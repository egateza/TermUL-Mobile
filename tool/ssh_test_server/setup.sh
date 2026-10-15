#!/bin/sh
# Server uji SSH sementara (user dan sshd uji), kredensial acak per pemasangan.
# Pemakaian: setup.sh <port-utama> <port-host-key-lain> <folder-keluaran>
# Dihapus dengan teardown.sh. Tidak ada kredensial yang masuk ke repo.
set -e
U=termul_t
P1="$1"
P2="$2"
OUT="$3"
FRASA='frasa-uji-bukan-kredensial'
PASS=$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)

id "$U" >/dev/null 2>&1 || useradd -m -s /bin/bash "$U"
echo "$U:$PASS" | chpasswd
mkdir -p /home/$U/.ssh && chmod 700 /home/$U/.ssh

K=/tmp/termul_keys
rm -rf "$K" && mkdir -p "$K"
ssh-keygen -q -t ed25519 -N '' -C uji -f "$K/key_ed"
ssh-keygen -q -t ed25519 -N "$FRASA" -C uji -f "$K/key_ed_pass"
ssh-keygen -q -t rsa -b 2048 -m PEM -N '' -C uji -f "$K/key_rsa"
ssh-keygen -q -t ecdsa -b 256 -m PEM -N '' -C uji -f "$K/key_ec"
ssh-keygen -q -t rsa -b 2048 -m PKCS8 -N '' -C uji -f "$K/key_pkcs8"
cat "$K"/key_ed.pub "$K"/key_ed_pass.pub "$K"/key_rsa.pub "$K"/key_ec.pub > /home/$U/.ssh/authorized_keys
chown -R $U:$U /home/$U/.ssh && chmod 600 /home/$U/.ssh/authorized_keys

mkdir -p /run/sshd /etc/ssh/termul_alt
for t in ed25519 rsa ecdsa; do
  [ -f /etc/ssh/termul_alt/ssh_host_${t}_key ] || ssh-keygen -q -t $t -N '' -f /etc/ssh/termul_alt/ssh_host_${t}_key
done

conf() { # port, hostkeydir, nama
  cat > /etc/ssh/termul_test_$1.conf <<EOF
Port $1
ListenAddress 0.0.0.0
HostKey $2/ssh_host_ed25519_key
HostKey $2/ssh_host_rsa_key
HostKey $2/ssh_host_ecdsa_key
PidFile /run/termul_test_$1.pid
UsePAM yes
PasswordAuthentication yes
ChallengeResponseAuthentication no
PubkeyAuthentication yes
AllowUsers $U
Subsystem sftp /usr/lib/openssh/sftp-server
PrintMotd no
EOF
}
conf "$P1" /etc/ssh
conf "$P2" /etc/ssh/termul_alt
for p in "$P1" "$P2"; do
  [ -f /run/termul_test_$p.pid ] && kill "$(cat /run/termul_test_$p.pid)" 2>/dev/null || true
  /usr/sbin/sshd -f /etc/ssh/termul_test_$p.conf
done

mkdir -p "$OUT"
cp "$K"/key_ed "$K"/key_ed_pass "$K"/key_rsa "$K"/key_ec "$K"/key_pkcs8 "$OUT"/
rm -rf "$K"
fp() { ssh-keygen -lf "$1" | cut -d' ' -f2; }
cat > "$OUT/config.json" <<EOF
{
  "host": "127.0.0.1",
  "port": $P1,
  "portAlt": $P2,
  "user": "$U",
  "password": "$PASS",
  "passphrase": "$FRASA",
  "keyDir": "$OUT",
  "fpEd25519": "$(fp /etc/ssh/ssh_host_ed25519_key.pub)",
  "fpAltEd25519": "$(fp /etc/ssh/termul_alt/ssh_host_ed25519_key.pub)",
  "fpRsa": "$(fp /etc/ssh/ssh_host_rsa_key.pub)",
  "version": "$(ssh -V 2>&1 | head -1 | tr -d "\"")"
}
EOF
echo "server uji siap di port $P1 dan $P2"
