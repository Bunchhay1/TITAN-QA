# Expected Security Headers

The banking API should return the following security headers:

| Header | Expected Value |
|--------|---------------|
| X-Content-Type-Options | nosniff |
| X-Frame-Options | DENY |
| Strict-Transport-Security | max-age=31536000; includeSubDomains |
| X-XSS-Protection | 1; mode=block |
| Content-Security-Policy | default-src 'self' |
| Referrer-Policy | no-referrer |

## Testing
Security header tests are included in the security test suite.
