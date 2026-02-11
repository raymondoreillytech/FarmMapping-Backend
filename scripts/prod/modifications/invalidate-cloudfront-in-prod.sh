aws --profile prod cloudfront create-invalidation \
  --distribution-id E7UL8RPSQC2O9 \
  --paths "/*"