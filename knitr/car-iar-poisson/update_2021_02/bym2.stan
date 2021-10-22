functions {
  /**
   * Return the log probability density for the vector of coefficients
   * under the ICAR model with unit variance, where the second two
   * arguments are parallel vectors of coefficients for adjacent
   * regions.  For example, a series of three coeffs phi[1:3] making
   * up a time series would have b1 = [phi[1], phi[2]]' and b2 =
   * [phi[2], phi[3]]'.
   * 
   * @param phi vector of varying effects
   * @param b1 parallel vector of elements of phi
   * @param b2 second parallel vector of adjacent elemens of phi
   * @return ICAR log density
   * @reject if b1 and b2 are not the same size
   */
  real soft_ctr_std_icar_lpdf(vector phi, vector b1, vector b2) {
    return -0.5 * dot_self(b1 - b2)
           + normal_lpdf(sum(phi) | 0, 0.001 * rows(phi));
    
    // ^^^: equiv normal_lpdf(b1 | b2, 1)
  }
  
  /**
   * Return the log probability density of the specified vector of
   * coefficients under the ICAR model with unit variance, where
   * adjacency is determined by the adjacency array. The adjacency
   * array contains two parallel arrays of adjacent element indexes.
   * For example, a series of four coefficients phi[1:4] making up a
   * time series would have adjacency array {{1, 2, 3}, {2, 3, 4}},
   * signaling that coefficient 1 is adjacent to coefficient 2, 2
   * adjacent to 3, and 3 adjacent to 4.
   *
   * @param phi vector of varying effects
   * @param adjacency parallel arrays of indexes of adjacent elements of phi
   * @return ICAR log probability density
   * @reject if the the adjacency matrix does not have two rows
   */
  real standard_icar_lpdf(vector phi, array[,] int adjacency) {
    if (size(adjacency) != 2) {
      reject("require 2rows for adjacency array;", " found rows = ", size(
      adjacency));
    }
    return soft_ctr_std_icar_lpdf(phi | phi[adjacency[1]], phi[adjacency[2]]);
  }
}
data {
  // spatial structure
  int<lower=0> I; // number of nodes
  int<lower=0> J; // number of edges
  array[2, J] int<lower=1, upper=I> edges; // node[1, j] adjacent to node[2, j]
  
  real tau; // scaling factor
  
  array[I] int<lower=0> y; // count outcomes
  vector<lower=0>[I] E; // exposure
  vector[I] x; // predictor
}
transformed data {
  vector[I] log_E = log(E);
}
parameters {
  real alpha; // intercept
  real beta; // covariate
  
  // spatial effects
  real<lower=0, upper=1> rho; // proportion of spatial effect that's spatially smoothed
  real<lower=0> sigma; // scale of spatial effects
  vector[I] theta; // standardized heterogeneous spatial effects
  vector[I] phi; // standardized spatially smoothed spatial effects
}
transformed parameters {
  // spatial effects (combine heterogeneous and spatially smoothed)
  vector[I] gamma = (sqrt(1 - rho) * theta + sqrt(rho / tau) * phi) * sigma;
}
model {
  y ~ poisson_log(log_E + alpha + x * beta + gamma * sigma); // co-variates
  
  alpha ~ normal(0, 1);
  beta ~ normal(0, 1);
  
  // spatial hyperpriors and priors
  sigma ~ normal(0, 1);
  rho ~ beta(0.5, 0.5);
  theta ~ normal(0, 1);
  phi ~ standard_icar(edges);
}
generated quantities {
  // posterior predictive checks
  vector[I] eta = log_E + alpha + x * beta + gamma * sigma;
  vector[I] y_prime = exp(eta);
  //   int y_rep[I,10];
  //   for (j in 1:10) {
  //     if (max(eta) > 20) {
  //       // avoid overflow in poisson_log_rng
  //       print("max eta too big: ", max(eta));  
  //       for (i in 1:I)
  // 	y_rep[i,j] = -1;
  //     } else {
  //       for (i in 1:I)
  //         y_rep[i,j] = poisson_log_rng(eta[i]);
  //     }
  //   }
  real logit_rho = log(rho / (1.0 - rho));
}

