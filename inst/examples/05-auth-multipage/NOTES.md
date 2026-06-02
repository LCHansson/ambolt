Login credentials for this demo:

  Username: demo
  Password: demo

The password is hashed at startup with `ambolt_hash_password()` so the
demo is self-contained — no users database needed. In a real app you
would persist the hashed password (e.g. in a database) and `verify`
against it inside `app$auth(verify = ...)`.
