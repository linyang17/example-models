// Zero-inflated Poisson binomial-mixture model

functions {
  /**
   * Returns log likelihood of N-mixture model
   * with 2 replicated observations using
   * bivariate Poisson distibution
   *
   * References
   * Dennis et al. (2015) Computational aspects of N-mixture models.
   *   Biometrics 71:237--246. DOI:10.1111/biom.12246
   * Stan users mailing list
   *   https://groups.google.com/forum/#!topic/stan-users/9mMsp1oB69g
   *
   * @param n          Number of observed individuals
   * @param log_lambda Log of Poisson mean of population size
   * @param p          Detection probability
   *
   * return Log probability
   */
  real bivariate_poisson_log_lpmf(array[] int n, real log_lambda, real p) {
    array[min(n) + 1] real s;
    real log_theta_1 = log_lambda + log(p) + log1m(p);
    real log_theta_0 = log_lambda + log(p) * 2;
    
    if (size(n) != 2) {
      reject("Size of n must be 2.");
    }
    if (p < 0 || p > 1) {
      reject("p must be in [0,1].");
    }
    for (u in 0 : min(n)) {
      s[u + 1] = poisson_log_lpmf(n[1] - u | log_theta_1)
                 + poisson_log_lpmf(n[2] - u | log_theta_1)
                 + poisson_log_lpmf(u | log_theta_0);
    }
    return log_sum_exp(s);
  }
  
  /**
   * Return log probability of Poisson Binomial Mixture
   *
   * @param y          Count
   * @param n          Population size
   * @param log_lambda Log of Poisson mean
   * @param p          Detection probability
   *
   * @return Log probability
   */
  real poisbin_lpmf(array[] int y, int n, real log_lambda, real p) {
    if (max(y) > n) {
      return negative_infinity();
    }
    return poisson_log_lpmf(n | log_lambda) + binomial_lpmf(y | n, p);
  }
}
data {
  int<lower=1> R; // Number of sites
  int<lower=1> T; // Number of replications; fixed as 2
  array[R, 2, 7] int<lower=-1> y; // Counts (-1:NA)
  array[R] int<lower=1, upper=7> first; // First occasion
  array[R] int<lower=1, upper=7> last; // Last occasion
  int<lower=0> K; // Upper bounds of population size
}
transformed data {
  array[R, 7] int<lower=0> max_y;
  array[R] int<lower=0> max_y_site;
  
  for (i in 1 : R) {
    for (k in 1 : (first[i] - 1)) {
      max_y[i, k] = 0;
    }
    for (k in (last[i] + 1) : 7) {
      max_y[i, k] = 0;
    }
    for (k in first[i] : last[i]) {
      max_y[i, k] = max(y[i, 1 : T, k]);
    }
    max_y_site[i] = max(max_y[i]);
  }
}
parameters {
  real<lower=0, upper=1> omega; // Suitability
  vector[7] alpha_lam; // Log abundance
  vector<lower=0, upper=1>[7] p; // Captue probability
}
model {
  // Priors
  // Implicit flat priors [0, 1] are used on omega and p.
  alpha_lam ~ normal(0, 10);
  
  // Likelihood
  for (i in 1 : R) {
    if (max_y_site[i]) {
      real lp = bernoulli_lpmf(1 | omega);
      
      for (k in first[i] : last[i]) {
        lp = lp
             + bivariate_poisson_log_lpmf(y[i, 1 : T, k] | alpha_lam[k], p[k]);
      }
      target += lp;
    } else {
      array[2] real lp;
      
      lp[1] = bernoulli_lpmf(0 | omega);
      lp[2] = bernoulli_lpmf(1 | omega);
      for (k in first[i] : last[i]) {
        lp[2] = lp[2]
                + bivariate_poisson_log_lpmf(y[i, 1 : T, k] | alpha_lam[k], p[k]);
      }
      target += log_sum_exp(lp);
    }
  }
}
generated quantities {
  array[7] int totalN; // Total pop. size across all sites
  real fit = 0;
  real fit_new = 0;
  vector[7] mean_abundance;
  
  {
    array[R, 7] int N; // Latent abundance state
    array[R, 7] real eval; // Expected values
    array[R, T, 7] int y_new;
    array[R] matrix[T, 7] E;
    array[R] matrix[T, 7] E_new;
    
    // Initialize N, E and E_new
    N = rep_array(0, R, 7);
    E[1] = rep_matrix(0, T, 7);
    E_new[1] = rep_matrix(0, T, 7);
    for (i in 2 : R) {
      E[i] = E[i - 1];
      E_new[i] = E_new[i - 1];
    }
    for (i in 1 : R) {
      real log_p_unobs; // Log of prob. site is suitable
      // but no indiv. observed.
      for (k in first[i] : last[i]) {
        vector[K + 1] lp;
        
        for (n in 0 : K) {
          lp[n + 1] = poisbin_lpmf(y[i, 1 : T, k] | n, alpha_lam[k], p[k]);
        }
        N[i, k] = categorical_rng(softmax(lp)) - 1;
      }
      
      if (max_y_site[i] == 0) {
        // Unobserved
        log_p_unobs = log(omega) + binomial_lpmf(0 | N[i], p) * T;
        if (bernoulli_rng(exp(log_p_unobs)) == 0) {
          // Site is not suitable
          for (k in first[i] : last[i]) {
            N[i, k] = 0;
          }
        }
      }
      
      for (k in first[i] : last[i]) {
        eval[i, k] = p[k] * N[i, k];
        for (j in 1 : T) {
          // Assess model fit using Chi-squared discrepancy
          // Compute fit statistic E for observed data
          E[i, j, k] = square(y[i, j, k] - eval[i, k]) / (eval[i, k] + 0.5);
          // Generate replicate data and compute fit stats for them
          y_new[i, j, k] = binomial_rng(N[i, k], p[k]);
          E_new[i, j, k] = square(y_new[i, j, k] - eval[i, k])
                           / (eval[i, k] + 0.5);
        }
      }
    }
    for (k in 1 : 7) {
      totalN[k] = sum(N[1 : R, k]);
    }
    for (i in 1 : R) {
      fit = fit + sum(E[i]);
      fit_new = fit_new + sum(E_new[i]);
    }
  }
  mean_abundance = exp(alpha_lam);
}
