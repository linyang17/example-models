data {
  int<lower=0> N;
  vector[N] dist;
  array[N] int<lower=0, upper=1> switc;
}
transformed data {
  matrix[N, 1] x = [(dist / 100)']';
}
parameters {
  real alpha;
  vector[2] beta;
}
model {
  switc ~ bernoulli_logit_glm(x, alpha, beta);
}

