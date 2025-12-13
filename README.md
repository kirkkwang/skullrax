# Skullrax

An easy programmatic way to create Valkyrie works in Hyrax 5 based applications for use in development.  Skullrax provides a simple, rails console approach to work creation with automatic field population.

## Features

- **Simple Work Creation**: Create works with minimal configuration
- **Intelligent Defaults**: Automatically fills required fields with placeholder data (very placeholder, not even the Faker kind, I'm talking "Test title" and "Test creator")
- **Controlled Vocabulary Support**: Intelligently handles Questioning Authority vocabularies
- **File Attachment**: Support for local and remote file uploads
- **Hyku Compatible**: Handles Hyku's authority naming quirks (e.g., `audience.yml` vs `audiences.yml`)
- **Error Handling**: Comprehensive error tracking for debugging

## Installation

Add this line to your Hyrax application's Gemfile:

```ruby
gem 'skullrax', github: 'kirkkwang/skullrax', branch: 'main'
```

And then execute:

```bash
$ bundle install
```

## Usage

### Basic Work Creation

Create a work with all defaults:

```ruby
Skullrax::ValkyrieWorkGenerator.new.create
```

### Customized Work Creation

Specify your own attributes:

```ruby
Skullrax::ValkyrieWorkGenerator.new(
  model: Monograph,
  user: current_user,
  title: ['Sample Work Title'],
  keyword: ['sample', 'work', 'keywords'],
  visibility: 'open'
).create
```

### Attaching Files

#### Single Local File

```ruby
Skullrax::ValkyrieWorkGenerator.new(
  file_paths: '/path/to/file.png'
).create
```

#### Multiple Files (Local and Remote)

```ruby
Skullrax::ValkyrieWorkGenerator.new(
  file_paths: [
    '/path/on/disk/local-image.jpg',
    '/path/to/another/file.txt'
  ]
).create
```

#### Remote Files

Download and attach files from URLs:

```ruby
Skullrax::ValkyrieWorkGenerator.new(
  file_paths: 'https://example.com/path/to/remote-image.jpg'
).create
```

#### Mixed Local and Remote Files

```ruby
Skullrax::ValkyrieWorkGenerator.new(
  file_paths: [
    'https://example.com/path/to/remote-image.jpg',
    'path/on/disk/local-image.jpg'
  ]
).create
```

### Error Handling

Check for errors after work creation:

```ruby
generator = Skullrax::ValkyrieWorkGenerator.new(title: ['My Work'])
generator.create

# if you don't get a success then try
generator.errors
```

Note: Errors caught during the save process are stored in `generator.errors`. Errors that occur before save will be raised as usual.

## How It Works

### Automatic Field Population

Skullrax automatically:
- Fills missing required fields with placeholder data (e.g., "Test title")
- Attempts to detect controlled vocabulary fields using the Questioning Authority gem and selects appropriate values from available authority lists

## Development

After checking out the repo, run:

```bash
docker-compose up
```

It takes a while to boot the Hyrax app but once that's done:

```bash
docker-compose exec web bash
```

Now in docker:
```bash
cd /skullrax
```

To run tests:

```bash
bundle exec rspec
```

## Why Skullrax?

Ever need to generate some quick metadata when you're developing in Hyrax?  Skullrax can help!

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kirkkwang/skullrax.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
