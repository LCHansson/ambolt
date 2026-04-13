# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in ambolt, **please do not open a
public issue**. Instead, email love.hansson@transportforetagen.se with:

- A description of the vulnerability
- Steps to reproduce
- Potential impact

You will receive a response within 48 hours. Security issues will be fixed
in a patch release as soon as possible, with credit to the reporter (unless
you prefer to remain anonymous).

## Scope

ambolt includes an authentication module (`app$auth()`) with session cookies,
rate limiting, and password hashing. Vulnerabilities in any of these areas are
considered high priority.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | Yes       |
