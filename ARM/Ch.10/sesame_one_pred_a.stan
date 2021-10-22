data {
  int<lower=0> N;
  vector[N] encouraged;
  vector[N] watched;
}
transformed data {
  matrix[N, 1] x = [encouraged']';
}
parameters {
  real alpha;
  vector[1] beta;
  real<lower=0> sigma;
}
model {
  watched ~ normal_id_glm(x, alpha, beta, sigma);
}

