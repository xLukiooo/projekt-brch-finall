#!/bin/bash
set -e

S3_BUCKET="projekt-brch-codedeploy-artifacts"
APP_DIR="/home/ec2-user/backend"

echo "--- Rozpoczęcie wdrożenia ---"

# Pobierz z S3 (S3 Gateway Endpoint nie wymaga internetu)
aws s3 cp "s3://$S3_BUCKET/backend-latest.zip" "/tmp/backend-latest.zip"

# Wyczyść i rozpakuj
rm -rf $APP_DIR/*
unzip -o "/tmp/backend-latest.zip" -d $APP_DIR

# Sprawdź czy mysqlclient jest już zainstalowany w dependencies 
echo "--- Sprawdzanie instalacji mysqlclient ---"
cd $APP_DIR
if [ -d "MySQLdb" ]; then
  echo "✓ MySQLdb już dostępny w dependencies"
else
  echo "ERROR: MySQLdb nie znaleziony w dependencies!"
  ls -la $APP_DIR | head -20
  exit 1
fi

# Ustaw właściciela
chown -R ec2-user:ec2-user $APP_DIR

# Debug i walidacja zmiennych środowiskowych RDS
echo "--- Debug zmiennych środowiskowych ---"
echo "DB_HOST: [${DB_HOST}]"
echo "DB_NAME: [${DB_NAME}]"
echo "DB_USER: [${DB_USER}]"
echo "DB_PORT: [${DB_PORT}]"
echo "DJANGO_SECRET_KEY: [${DJANGO_SECRET_KEY:0:10}...]"

# Walidacja krytycznych zmiennych RDS
echo "--- Walidacja zmiennych RDS ---"
if [ -z "$DB_HOST" ]; then
  echo "BŁĄD: DB_HOST jest pusty! Sprawdź GitHub Secrets."
  echo "Dostępne zmienne środowiskowe:"
  env | grep -E "(DB_|DJANGO_)" | sort
  exit 1
fi

if [ "$DB_HOST" = "localhost" ]; then
  echo "BŁĄD: DB_HOST to localhost zamiast RDS endpoint!"
  echo "DB_HOST powinien być adresem RDS, np: xxx.rds.amazonaws.com"
  exit 1
fi

if [ -z "$DB_PASSWORD" ]; then
  echo "BŁĄD: DB_PASSWORD jest pusty! Sprawdź GitHub Secrets."
  exit 1
fi

if [ -z "$DB_NAME" ]; then
  echo "BŁĄD: DB_NAME jest pusty! Sprawdź GitHub Secrets."
  exit 1
fi

if [ -z "$DB_USER" ]; then
  echo "BŁĄD: DB_USER jest pusty! Sprawdź GitHub Secrets."
  exit 1
fi

echo "✓ Wszystkie zmienne RDS są poprawne"

# Test połączenia z RDS (opcjonalnie)
echo "--- Test połączenia TCP z RDS ---"
timeout 10 bash -c "</dev/tcp/$DB_HOST/3306" && echo "✓ RDS dostępny na porcie 3306" || {
  echo "✗ Nie można połączyć się z RDS $DB_HOST:3306"
  echo "Sprawdź:"
  echo "1. Czy RDS jest uruchomiony"
  echo "2. Czy Security Groups pozwalają na połączenie"
  echo "3. Czy endpoint RDS jest poprawny"
  exit 1
}

# WAŻNE: Utwórz katalogi logów PRZED uruchomieniem Django
echo "--- Tworzenie katalogów logów ---"
sudo mkdir -p /var/log/gunicorn
sudo chown ec2-user:ec2-user /var/log/gunicorn
sudo chmod 755 /var/log/gunicorn
echo "✓ Katalogi logów utworzone"

# Utwórz plik .env ze zmiennymi środowiskowymi
# Te zmienne są przekazywane jako zmienne środowiskowe przez SSM
echo "--- Tworzenie pliku .env ---"
cat > $APP_DIR/.env << ENV_EOF
DB_HOST=${DB_HOST}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_PORT=3306
AWS_REGION=us-east-1
DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY}
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=*
DJANGO_CORS_ALLOWED_ORIGINS=${FRONTEND_URL}
ENV_EOF

chmod 600 $APP_DIR/.env
chown ec2-user:ec2-user $APP_DIR/.env

# Sprawdź utworzony plik .env (bez haseł)
echo "--- Sprawdzenie pliku .env ---"
echo "Zawartość .env (bez haseł):"
cat $APP_DIR/.env | grep -v PASSWORD | grep -v SECRET_KEY

# Uruchom migracje
echo "--- Uruchamianie migracji ---"
sudo -u ec2-user bash -c "
  cd $APP_DIR
  export PYTHONPATH=$APP_DIR
  # Załaduj zmienne środowiskowe z .env
  export \$(cat $APP_DIR/.env | grep -v '#' | xargs)
  
  # Debug Django przed migracjami
  echo \"Django sprawdza konfigurację bazy danych...\"
  echo \"Łączenie z: \$DB_USER@\$DB_HOST:\$DB_PORT/\$DB_NAME\"
  
  # Sprawdź czy Django może się połączyć
  python3 -c \"
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'myproject.settings')
django.setup()
from django.db import connection
try:
    with connection.cursor() as cursor:
        cursor.execute('SELECT 1')
        print('✓ Połączenie z bazą danych działa!')
except Exception as e:
    print(f'✗ Błąd połączenia z bazą danych: {e}')
    exit(1)
\" || {
    echo 'BŁĄD: Django nie może połączyć się z bazą danych'
    echo 'Sprawdź logi powyżej i konfigurację RDS'
    exit 1
  }
  
  echo \"Uruchamianie migracji Django...\"
  python3 manage.py migrate --noinput
"

# Restart Gunicorn
echo "--- Restart Gunicorn ---"
if [ -f "$APP_DIR/gunicorn.service" ]; then
  cp $APP_DIR/gunicorn.service /etc/systemd/system/gunicorn.service
  systemctl daemon-reload
fi
systemctl restart gunicorn

# Sprawdź status Gunicorn
sleep 3
if systemctl is-active --quiet gunicorn; then
  echo "✓ Gunicorn działa poprawnie"
else
  echo "✗ Gunicorn nie uruchomił się - sprawdzanie logów..."
  journalctl -u gunicorn -n 50 --no-pager
  exit 1
fi

rm /tmp/backend-latest.zip
echo "--- Wdrożenie zakończone pomyślnie ---"
echo "✓ RDS: $DB_HOST"
echo "✓ Baza danych: $DB_NAME"
echo "✓ Użytkownik: $DB_USER"
echo "✓ Django: Migracje wykonane"
echo "✓ Gunicorn: Uruchomiony"