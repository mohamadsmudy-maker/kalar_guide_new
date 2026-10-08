# ✅ Security Checklist

## 🔐 Authentication

- [x] SHA-256 + Salt بۆ پاسۆرد
- [x] Session Management
- [x] Auto-logout
- [ ] JWT Tokens
- [ ] 2FA (Two-Factor Auth)
- [ ] Rate Limiting ی Login
- [ ] Account Lockout دوای ٥ هەوڵ

## 🛡️ Authorization

- [x] RLS Policies چالاک
- [x] Role-based Access (admin, vendor, customer)
- [ ] Scope-based Access
- [ ] Row-level Security ی تەواو

## 🔒 Data Protection

- [x] HTTPS لە Production
- [x] Password Hashing
- [x] RLS Policies
- [x] Storage Policies
- [ ] Encryption at Rest
- [ ] Encryption in Transit
- [ ] Backups

## 🔑 API Security

- [x] API Keys لە .env
- [x] --dart-define بۆ Release
- [ ] Rate Limiting
- [ ] Request Validation
- [ ] CORS
- [ ] API Gateway

## 📱 App Security

- [x] No Hardcoded Secrets
- [x] Input Validation
- [x] Error Handling
- [ ] Code Obfuscation
- [ ] Certificate Pinning
- [ ] Root Detection
- [ ] Anti-Tampering

## 📝 Best Practices

- [x] No SQL Injection
- [x] No XSS
- [x] No CSRF
- [ ] Security Headers
- [ ] Audit Logs
- [ ] Monitoring
- [ ] Incident Response

## 🧪 Testing

- [ ] Penetration Testing
- [ ] Vulnerability Scanning
- [ ] Code Review
- [ ] Security Training

---

## 🎯 Priority

### 🔴 گرنگ
1. Rate Limiting
2. JWT Tokens
3. Code Obfuscation

### 🟡 مامناوەند
4. 2FA
5. Audit Logs
6. Certificate Pinning

### 🟢 باش
7. Root Detection
8. Penetration Testing
9. Monitoring