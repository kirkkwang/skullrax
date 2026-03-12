FROM ghcr.io/samvera/hyrax-dev:latest

COPY . /skullrax

# Upgrade dassie from Rails 6.1 to 7.2 in-place before bundling
RUN sed -i "s/gem 'rails', '6.1.7.10'/gem 'rails', '~> 7.2', '< 8.0'/" Gemfile && \
    sed -i "s/config.load_defaults 6.1/config.load_defaults 7.2/" config/application.rb && \
    sed -i "s/config.action_dispatch.show_exceptions = false/config.action_dispatch.show_exceptions = :none/" config/environments/test.rb

# Rails 7 compatibility: defer curation_concerns constantize until after models are autoloaded.
# In Rails 6.1 this ran fine in an initializer; Zeitwerk needs it in to_prepare instead.
RUN sed -i "s/Bulkrax.default_work_type = Hyrax.config.curation_concerns.first.to_s/Rails.application.reloader.to_prepare { Bulkrax.default_work_type ||= Hyrax.config.curation_concerns.first.to_s }/" config/initializers/hyrax.rb

# Rails 7 compatibility: collection_class and file_set_class trigger CollectionResource autoloading
# which calls ValkyrieLazyMigration.migrating -> Wings::ModelRegistry before Wings is loaded.
# Skullrax does not use Bulkrax so these assignments are safe to skip.
RUN sed -i "s/config.collection_model_class = Hyrax.config.collection_class/# config.collection_model_class = Hyrax.config.collection_class/" config/initializers/bulkrax.rb && \
    sed -i "s/config.file_model_class = Hyrax.config.file_set_class/# config.file_model_class = Hyrax.config.file_set_class/" config/initializers/bulkrax.rb

ENV BUNDLE_GEMFILE=/app/samvera/hyrax-webapp/Gemfile.dassie

RUN echo "gem 'skullrax', path: '/skullrax'" >> Gemfile && \
    echo "gem 'simplecov', require: false" >> Gemfile && \
    bundle install

ENV DATABASE_URL=postgresql://dummy:dummy@localhost/dummy

RUN bundle exec rails generate skullrax:install
RUN bundle exec rails assets:precompile
