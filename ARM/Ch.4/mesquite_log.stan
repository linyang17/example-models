data {
  int<lower=0> N;
  vector[N] weight;
  vector[N] diam1;
  vector[N] diam2;
  vector[N] canopy_height;
  vector[N] total_height;
  vector[N] density;
  vector[N] group;
}
transformed data {
  // log transformations
  vector[N] log_weight = log(weight);
  vector[N] log_diam1 = log(diam1);
  vector[N] log_diam2 = log(diam2);
  vector[N] log_canopy_height = log(canopy_height);
  vector[N] log_total_height = log(total_height);
  vector[N] log_density = log(density);
  matrix[N, 6] x = [log_diam1', log_diam2', log_canopy_height',
                    log_total_height', log_density', group']';
}
parameters {
  real alpha;
  vector[6] beta;
  real<lower=0> sigma;
}
model {
  log_weight ~ normal_id_glm(x, alpha, beta, sigma);
}

