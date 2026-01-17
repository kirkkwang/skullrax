#!/bin/sh
set -e

# Check and create/migrate test database
if ! PGPASSWORD=hyrax_password psql -h postgres -U hyrax_user -lqt | cut -d \| -f 1 | grep -qw hyrax_test; then
  echo 'Creating and migrating test database...'
  RAILS_ENV=test bundle exec rails db:create db:migrate
else
  echo 'Test database already exists, skipping creation'
fi

# Check and migrate development database
if ! PGPASSWORD=hyrax_password psql -h postgres -U hyrax_user hyrax_development -tAc "SELECT 1 FROM schema_migrations LIMIT 1" 2>/dev/null | grep -q 1; then
  echo 'Running development database migrations...'
  bundle exec rails db:migrate
else
  echo 'Development database migrations already run'
fi

# Check and seed development database
if ! PGPASSWORD=hyrax_password psql -h postgres -U hyrax_user hyrax_development -tAc "SELECT 1 FROM users WHERE email='admin@example.com' LIMIT 1" 2>/dev/null | grep -q 1; then
  echo 'Seeding development database...'
  bundle exec rails db:seed
else
  echo 'Database already seeded, skipping'
fi
