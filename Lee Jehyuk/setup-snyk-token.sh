#!/bin/bash

# Snyk 토큰을 AWS Parameter Store에 저장하는 스크립트

echo "Snyk API 토큰을 입력하세요:"
read -s SNYK_TOKEN

aws ssm put-parameter \
    --name "/snyk/api-token" \
    --value "$SNYK_TOKEN" \
    --type "SecureString" \
    --region ap-northeast-2 \
    --overwrite

echo "Snyk 토큰이 Parameter Store에 저장되었습니다."
