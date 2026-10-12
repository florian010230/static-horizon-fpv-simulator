class_name UpdateKey
extends RefCounted

## The public half of the key that signs update packs (RSA, PEM). The
## private half lives only on the user's Mac, outside the repo (see
## tools/make_update.sh). Empty = in-game updates are off: the Updates
## screen only offers the release page.
const PUBLIC_PEM: String = ""
