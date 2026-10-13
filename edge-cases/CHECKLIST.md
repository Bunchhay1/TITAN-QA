# Edge Case Test Checklist

## Boundary Values
- [ ] Zero amount transfer
- [ ] Minimum valid amount (0.01)
- [ ] Maximum valid amount
- [ ] Negative amount
- [ ] Amount exceeding daily limit

## Missing Fields
- [ ] Login without email
- [ ] Login without password
- [ ] Transfer without amount
- [ ] Transfer without destination
- [ ] Account creation without type

## Invalid Formats
- [ ] Invalid email format
- [ ] Invalid phone format
- [ ] Non-numeric amount
- [ ] Invalid date format
- [ ] Special characters in ID fields

## Concurrent Operations
- [ ] Double transfer (race condition)
- [ ] Simultaneous deposit and withdraw
- [ ] Multiple OTP requests

## Expired Resources
- [ ] Expired auth token
- [ ] Expired OTP
- [ ] Expired QR code
