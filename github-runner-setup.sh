set -euo pipefail

sudo apt update
sudo apt install -y libatomic1

sudo apt-get install -y \
    libnspr4 \
    libnss3 \
    libatk1.0-0t64 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2t64 \
    libatspi2.0-0t64
