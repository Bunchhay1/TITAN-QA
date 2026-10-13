# Rate Limiting Policy

## Login Endpoint
- Max 5 attempts per minute per IP
- Lockout after 10 failed attempts
- Reset after 15 minutes

## OTP Endpoint
- Max 3 OTP requests per 10 minutes
- OTP valid for 5 minutes

## Transfer Endpoint
- Max 10 transfers per minute
- Daily transfer limit: $50,000
