# API Endpoints Reference

## Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/v2/auth/login | User login |
| POST | /api/v2/auth/logout | User logout |
| POST | /api/v2/auth/refresh | Refresh token |
| POST | /api/v2/auth/otp/verify | Verify OTP |

## Accounts
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | /api/v2/accounts | List accounts |
| POST | /api/v2/accounts | Create account |
| GET | /api/v2/accounts/:id | Get account |
| PUT | /api/v2/accounts/:id | Update account |
| DELETE | /api/v2/accounts/:id | Close account |
