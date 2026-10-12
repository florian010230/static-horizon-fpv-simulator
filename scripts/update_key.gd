class_name UpdateKey
extends RefCounted

## The public half of the key that signs update packs (RSA, PEM). The
## private half lives only on the user's Mac, outside the repo (see
## tools/make_update.sh). Empty = in-game updates are off: the Updates
## screen only offers the release page.
const PUBLIC_PEM: String = """-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEA7LFPndu2LHC5nH8r3ST0
OZ7UoDliJr5e427FQ55CQjGq015G5eK9/owZMDWnMLYbZgAjoKV7wMS5sHeoi/NO
fLkB0hhuOFmRVeRn/f0FHD7yWiuXTGXc5AHZyRrze96vMScDh89m9Zt9Z2iUYWUQ
yLGw8crJ8JPI7NlD9RMkwvD3WNKyP4JS21p+N0osLL+JUpyHDKWugxgvQGmYvkVz
f+ktQP0LNLlE9ooWjjJfc/zT/41S/9Wtb4zd3zmuDSTtlrtWHuUl6dLQ82+tMQ4A
PuHpBUh8iimn9LJXxY4sM0RVWXAuTf0Dc9JowJa+p0n0nqJoe7sd8tYRngLEljKA
veYUpulcTRUdgkjGQD7QnOkKqArMELmtUoc0wYcscXyKCTJv1POpMlosMOT1yuuM
aLGD/qZa0hS8uFOwdmMgRRHHYlHZ4b92mvsc14RSAQiHsUatyiEpgIupde5qfojW
VaWYCUIU1pyOLlQHypUc/MqiFYGCnDsoHGG638EjQeJ1AgMBAAE=
-----END PUBLIC KEY-----
"""
