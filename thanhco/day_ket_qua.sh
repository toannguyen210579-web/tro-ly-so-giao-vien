#!/usr/bin/env bash
# Đẩy các tệp kết quả lên nhánh thanh-co-ket-qua (tạo nhánh mới nếu chưa có).
# Cách dùng: day_ket_qua.sh <thư mục con> <tệp 1> [tệp 2 ...]
set -euo pipefail
con="$1"; shift
url="https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
rm -rf /tmp/kq
if git ls-remote --exit-code --heads "$url" thanh-co-ket-qua >/dev/null 2>&1; then
  git clone -q --depth 1 --branch thanh-co-ket-qua "$url" /tmp/kq
else
  mkdir -p /tmp/kq && git -C /tmp/kq init -q -b thanh-co-ket-qua && git -C /tmp/kq remote add origin "$url"
fi
mkdir -p "/tmp/kq/$con"
for f in "$@"; do cp "$f" "/tmp/kq/$con/"; done
cd /tmp/kq
git config user.name "may-dung-thanh-co"
git config user.email "may-dung-thanh-co@users.noreply.github.com"
git add -A
git commit -q -m "ket qua $con $(date -u +%Y%m%dT%H%M%S)" || { echo "khong co gi moi"; exit 0; }
for i in 1 2 3; do
  git push -q origin HEAD:thanh-co-ket-qua && exit 0
  git fetch -q --depth 1 origin thanh-co-ket-qua && git rebase -q origin/thanh-co-ket-qua || true
done
exit 1
