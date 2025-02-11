// Stacks: robust regression and ridge regression 
// http://mathstat.helsinki.fi/openbugs/Examples/Stacks.html
// Model f) t error ridge regression

data {
  int<lower=0> N;
  int<lower=0> p;
  array[N] real Y;
  matrix[N, p] x;
}
// to standardize the x's 
transformed data {
  matrix[N, p] z;
  row_vector[p] mean_x;
  array[p] real sd_x;
  real d;
  
  for (j in 1 : p) {
    mean_x[j] = mean(col(x, j));
    sd_x[j] = sd(col(x, j));
    for (i in 1 : N) {
      z[i, j] = (x[i, j] - mean_x[j]) / sd_x[j];
    }
  }
  d = 4; // degrees of freedom for t
}
parameters {
  real beta0;
  vector[p] beta;
  real<lower=0> sigmasq;
  real<lower=0> phi;
}
transformed parameters {
  real<lower=0> sigma;
  vector[N] mu;
  
  sigma = sqrt(d * sigmasq / (d - 2)); // t errors on d degrees of freedom
  mu = beta0 + z * beta;
}
model {
  beta0 ~ normal(0, 316);
  phi ~ gamma(0.01, 0.01);
  beta ~ normal(0, sqrt(phi));
  sigmasq ~ inv_gamma(.001, .001);
  Y ~ student_t(d, mu, sqrt(sigmasq));
}
generated quantities {
  real b0;
  vector[p] b;
  real outlier_1;
  real outlier_3;
  real outlier_4;
  real outlier_21;
  
  for (j in 1 : p) {
    b[j] = beta[j] / sd_x[j];
  }
  b0 = beta0 - mean_x * b;
  
  outlier_1 = step(fabs((Y[3] - mu[3]) / sigma) - 2.5);
  outlier_3 = step(fabs((Y[3] - mu[3]) / sigma) - 2.5);
  outlier_4 = step(fabs((Y[4] - mu[4]) / sigma) - 2.5);
  outlier_21 = step(fabs((Y[21] - mu[21]) / sigma) - 2.5);
}
