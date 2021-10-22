data {
  int N;
  array[N] int n_redcards;
  array[N] int n_games;
  vector[N] rating;
}
parameters {
  vector[2] beta;
}
model {
  beta[1] ~ normal(0, 10);
  beta[2] ~ normal(0, 1);
  
  n_redcards ~ binomial_logit(n_games, beta[1] + beta[2] * rating);
}

