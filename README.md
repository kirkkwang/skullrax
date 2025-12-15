# Skullrax

An easy programmatic way to create Valkyrie works in Hyrax 5 based applications for use in development.  Skullrax provides a simple, Rails console approach to work creation with automatic field population.

## Features

- **Simple Work Creation**: Create works with minimal configuration
- **Intelligent Defaults**: Automatically fills required fields with placeholder data (very placeholder, not even the Faker kind, I'm talking "Test title" and "Test creator")
- **Auto-fill Mode**: Optionally populate all settable properties, not just required ones
- **Flexible Property Control**: Exclude specific properties from being set
- **Controlled Vocabulary Support**: Intelligently handles Questioning Authority vocabularies
- **Geonames Integration**: Automatically looks up location URIs from plain text queries
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

Create a work with all required fields populated:
```ruby
Skullrax::ValkyrieWorkGenerator.new.create
```

### Auto-fill All Settable Properties

Use `autofill: true` to populate all settable properties, not just required ones:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  autofill: true
).create
```

### Excluding Properties

Exclude specific properties from being set using `except:`:
```ruby
# Exclude a single property
Skullrax::ValkyrieWorkGenerator.new(
  autofill: true,
  except: :video_embed
).create

# Exclude multiple properties
Skullrax::ValkyrieWorkGenerator.new(
  autofill: true,
  except: [:based_near, :subject]
).create
```

### Customized Work Creation

Specify your own attributes:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  model: Monograph,
  title: ['Sample Work Title'],
  keyword: ['sample', 'work', 'keywords'],
  visibility: 'open'
).create
```

### Visibility Settings

Control work visibility including embargoes and leases:

#### Basic Visibility

Set simple visibility levels (defaults to `restricted` if not specified):
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  visibility: 'open'  # or 'authenticated', 'restricted'
).create
```

#### Embargo

Restrict access until a future date, then change to a different visibility:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  visibility: 'embargo',
  visibility_during_embargo: 'restricted',
  embargo_release_date: Date.today + 6.months,
  visibility_after_embargo: 'open'
).create
```

#### Lease

Make work openly available for a limited time, then restrict access:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  visibility: 'lease',
  visibility_during_lease: 'open',
  lease_expiration_date: '2030-12-31',  # Date or String accepted
  visibility_after_lease: 'authenticated'
).create
```

**Note:** Both `embargo_release_date` and `lease_expiration_date` accept either `Date` objects or date strings - Hyrax forms will handle the conversion automatically.

### Geonames Location Lookup

Skullrax can automatically look up Geonames URIs from plain text location queries:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  based_near: 'San Diego'
).create
# Automatically resolves to: https://sws.geonames.org/5391811/
```

You can also use exact URIs if you prefer:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  based_near: 'https://sws.geonames.org/5391811/'
).create
```

**Note**: Geonames lookup requires a username. Set the `GEONAMES_USERNAME` environment variable or it defaults to 'scientist' for testing.

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

### File Set Metadata

You can specify metadata for individual file sets when attaching files:

#### Multiple Files with Corresponding Metadata
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  file_paths: ['/path/to/file1.pdf', '/path/to/file2.jpg'],
  file_set_params: [
    { title: 'Contract Document', description: 'Legal contract' },
    { title: 'Product Photo', keyword: ['product', 'marketing'] }
  ]
).create
```

The order of `file_set_params` corresponds to the order of `file_paths`.

#### Single File Set Metadata

If you provide a single hash instead of an array, it applies only to the first file:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  file_paths: ['/path/to/file1.pdf', '/path/to/file2.jpg'],
  file_set_params: { title: 'Contract Document', description: 'Legal contract' }
).create
# Only file1.pdf gets the metadata; file2.jpg uses defaults
```

#### Automatic Value Wrapping

Values are automatically wrapped in arrays (Hyrax expects array values for most fields):
```ruby
# These are equivalent:
file_set_params: { title: 'My Title' }
file_set_params: { title: ['My Title'] }
```

#### Unsupported Properties

Unsupported properties are silently ignored - Hyrax will filter them out based on `FileSet.user_settable_attributes`:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  file_paths: '/path/to/file.pdf',
  file_set_params: {
    title: 'Valid Title',
    invalid_field: 'This will be ignored'
  }
).create
# Only 'title' is applied; 'invalid_field' is skipped
```

### Error Handling

Check for errors after work creation:
```ruby
generator = Skullrax::ValkyrieWorkGenerator.new(title: ['My Work'])
result = generator.create

# Check if creation was successful
if result.success?
  puts "Work created: #{generator.work.id}"
else
  puts "Errors: #{generator.errors}"
end
```

**Note**: Errors caught during the save process are stored in `generator.errors`. Errors that occur before save will be raised as usual.

## How It Works

### Automatic Field Population

Skullrax automatically:
- Fills missing required fields with placeholder data (e.g., "Test title")
- Detects controlled vocabulary fields using the Questioning Authority gem and selects valid values from available authority lists
- Looks up Geonames URIs when given plain text location names
- Handles special Hyrax fields like `based_near` that use nested attributes

### Auto-fill Mode

When `autofill: true` is enabled, Skullrax will populate all properties that have form metadata in the model's schema, not just required ones. This is useful for:
- Creating fully populated test works
- Exploring all available fields on a work type
- Generating sample data for development

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

Ever need to generate some quick metadata when you're developing in Hyrax? Skullrax can help! Named after Bulk and Skull from Power Rangers, Skullrax is the simpler, more straightforward alternative to Bulkrax for programmatic work creation.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kirkkwang/skullrax.

## License

The gem is available as open source under the terms of the [Apache 2.0 License](https://opensource.org/licenses/Apache-2.0).
