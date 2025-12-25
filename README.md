# Skullrax

An easy programmatic way to create Valkyrie works in Hyrax 5 based applications for use in development.  Skullrax provides a simple, Rails console approach to work creation with automatic field population.

## Features

- **Simple Resource Creation**: Create works and collections with minimal configuration
- **Intelligent Defaults**: Automatically fills required fields with placeholder data
- **Auto-fill Mode**: Optionally populate all settable properties, not just required ones
- **Flexible Property Control**: Exclude specific properties from being set
- **Controlled Vocabulary Support**: Intelligently handles Questioning Authority vocabularies
- **Geonames Integration**: Automatically looks up location URIs from plain text queries
- **File Attachment**: Support for local and remote file uploads
- **File Set Metadata**: Set individual metadata for each attached file
- **Visibility Management**: Configure visibility including embargoes and leases
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
Skullrax::ValkyrieWorkCreator.new.create
```

It can create a work by using the legacy Active Fedora models as well:
```ruby
Skullrax::ActiveFedoraWorkGenerator.new(model: GenericWork).create
```
This will still create a GenericWorkResource.

### Auto-fill All Settable Properties

Use `autofill: true` to populate all settable properties, not just required ones:
```ruby
Skullrax::ValkyrieWorkCreator.new(
  autofill: true
).create
```

### Excluding Properties

Exclude specific properties from being set using `except:`:
```ruby
# Exclude a single property
Skullrax::ValkyrieWorkCreator.new(
  autofill: true,
  except: :video_embed
).create

# Exclude multiple properties
Skullrax::ValkyrieWorkCreator.new(
  autofill: true,
  except: [:based_near, :subject]
).create
```

### Customized Work Creation

Specify your own attributes:
```ruby
Skullrax::ValkyrieWorkCreator.new(
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
Skullrax::ValkyrieWorkCreator.new(
  visibility: 'open'  # or 'authenticated', 'restricted'
).create
```

#### Embargo

Restrict access until a future date, then change to a different visibility:
```ruby
Skullrax::ValkyrieWorkCreator.new(
  visibility: 'embargo',
  visibility_during_embargo: 'restricted',
  embargo_release_date: Date.today + 6.months,
  visibility_after_embargo: 'open'
).create
```

#### Lease

Make work openly available for a limited time, then restrict access:
```ruby
Skullrax::ValkyrieWorkCreator.new(
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
Skullrax::ValkyrieWorkCreator.new(
  based_near: 'San Diego'
).create
# Automatically resolves to: https://sws.geonames.org/5391811/
```

You can also use exact URIs if you prefer:
```ruby
Skullrax::ValkyrieWorkCreator.new(
  based_near: 'https://sws.geonames.org/5391811/'
).create
```

**Note**: Geonames lookup requires a username. Set the `GEONAMES_USERNAME` environment variable or it defaults to 'scientist' for testing.

### Attaching Files

#### Single Local File
```ruby
Skullrax::ValkyrieWorkCreator.new(
  file_paths: '/path/to/file.png'
).create
```

#### Multiple Files (Local and Remote)
```ruby
Skullrax::ValkyrieWorkCreator.new(
  file_paths: [
    '/path/on/disk/local-image.jpg',
    '/path/to/another/file.txt'
  ]
).create
```

#### Remote Files

Download and attach files from URLs:
```ruby
Skullrax::ValkyrieWorkCreator.new(
  file_paths: 'https://example.com/path/to/remote-image.jpg'
).create
```

#### Mixed Local and Remote Files
```ruby
Skullrax::ValkyrieWorkCreator.new(
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
Skullrax::ValkyrieWorkCreator.new(
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
Skullrax::ValkyrieWorkCreator.new(
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
Skullrax::ValkyrieWorkCreator.new(
  file_paths: '/path/to/file.pdf',
  file_set_params: {
    title: 'Valid Title',
    invalid_field: 'This will be ignored'
  }
).create
# Only 'title' is applied; 'invalid_field' is skipped
```

### CSV Import

Skullrax supports batch imports via CSV, allowing you to create collections, works, and file sets in a single operation.

#### Basic CSV Import

Import collections and works from a CSV string:
```ruby
csv = <<~CSV
  model,title,creator,visibility
  CollectionResource,Related Collection,Collection Creator,open
  GenericWorkResource,Work in Collection,Work Creator,open
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.import
```

#### Active Fedora models

You can also use Active Fedora models by specifying them in the `model` column:
```ruby
csv = <<~CSV
  model,title,creator,visibility
  Collection,Related Collection,Collection Creator,open
  GenericWork,Work in Collection,Work Creator,open
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.import
```

#### Accessing Imported Resources

After import, you can access the created resources:
```ruby
importer = Skullrax::CsvImporter.new(csv:)
importer.import

# Access all resources
importer.resources  # => [collection, work, ...]

# Filter by type
importer.collections  # => [collection1, collection2]
importer.works       # => [work1, work2]
importer.file_sets   # => [file_set1, file_set2]
```

#### Explicit Collection Relationships

Control collection membership explicitly using `member_of_collection_ids`:
```ruby
csv = <<~CSV
  model,id,title,creator,member_of_collection_ids,visibility
  Collection,col-789,Related Collection,Collection Creator,,open
  GenericWork,,Work in Collection,Work Creator,col-789,open
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.import
```

**Note:** You can set custom IDs for collections using the `id` column. Works will be added to the collection with the matching ID.

#### Batched Import Structure

Skullrax automatically assigns works to collections based on CSV order. Works are added to the most recently defined collection above them:
```ruby
csv = <<~CSV
  model,title,creator,visibility
  Collection,New Collection,Collection Creator,open
  GenericWork,Work1 in New Collection,Work Creator,open
  GenericWork,Work2 in New Collection,Work Creator,open
  Collection,Another Collection,Another Creator,open
  GenericWork,Work1 in Another Collection,Another Creator,open
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.import
```

This creates:
- "New Collection" containing Work1 and Work2
- "Another Collection" containing Work1

**Important:** Standalone works (not belonging to any collection) must appear before the first collection:
```ruby
csv = <<~CSV
  model,title,creator,visibility
  GenericWork,Standalone Work1,Standalone Creator,open
  GenericWork,Standalone Work2,Standalone Creator,open
  Collection,New Collection,Collection Creator,open
  GenericWork,Work1 in New Collection,Work Creator,open
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.import
```

#### File Attachments in CSV

##### Simple File Attachment

Add a single file to a work using the `file` column:
```ruby
csv = <<~CSV
  title,creator,visibility,file
  Work with File,Work Creator,open,/path/to/file1.jpg
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.import
```

##### Explicit File Sets

Create file sets with custom metadata by including `FileSet` rows after works:
```ruby
csv = <<~CSV
  model,title,creator,visibility,file
  Collection,New Collection,Collection Creator,open,
  GenericWork,Work1 in Collection,Work Creator,open,
  FileSet,FileSet1 for Work1,FileSet Creator,open,/path/to/file1.jpg
  FileSet,FileSet2 for Work1,FileSet Creator,open,/path/to/file2.jpg
  GenericWork,Work2 in Collection,Work Creator,open,
  FileSet,FileSet1 for Work2,FileSet Creator,open,https://example.com/file3.jpg
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.import
```

This creates:
- "Work1 in Collection" with 2 file sets
- "Work2 in Collection" with 1 file set

File sets are automatically attached to the work immediately above them in the CSV.

##### Remote Files

File sets support both local paths and remote URLs:
```ruby
csv = <<~CSV
  model,title,file
  GenericWork,Work with Remote File,
  FileSet,Remote Image,https://example.com/image.jpg
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.import
```

#### Delimited Values

Split multi-value fields using semicolon (`;`) delimiter:
```ruby
csv = <<~CSV
  model,title,creator,visibility,subject,keyword
  GenericWork,Work with Multiple Values,Work Creator,open,History;Art;Science,sample;test;demo
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.import
```

The `subject` field becomes `['History', 'Art', 'Science']` and `keyword` becomes `['sample', 'test', 'demo']`.

##### Custom Delimiter

Use a different delimiter if needed:
```ruby
csv = <<~CSV
  model,title,creator,visibility,subject
  GenericWork,Work with Subjects,Work Creator,open,History|Art|Science
CSV

importer = Skullrax::CsvImporter.new(csv:, delimiter: '|')
importer.import
```

**Note:** Delimiters only apply to fields that are defined as multi-value in your model's schema (fields with `form` metadata). Single-value fields like `title` are not split.

#### Supported Model Types

CSV import supports:
- **Collection** - Collections (uses `Hyrax.config.collection_class`)
- **Curation Concerns** - Any registered curation concern (e.g., `GenericWorkResource`, `Monograph`, `ImageResource` or `GenericWork`, `Image`)
- **FileSet** - File sets with attachments

#### CSV Column Reference

Common columns supported:
- `model` - Required. The resource type to create
- `id` - Optional. Custom ID for the resource
- `title` - Work/collection title
- `creator` - Creator name(s)
- `visibility` - Access level: `open`, `authenticated`, `restricted`
- `file` - File path or URL (for simple file attachment to works)
- `member_of_collection_ids` - Explicit collection membership
- Plus any other property supported by your work/collection model

For file sets:
- `file` - Required. Path or URL to the file
- Any other file set metadata fields (e.g., `title`, `creator`, `keyword`)

### Error Handling

Check for errors after work creation:
```ruby
generator = Skullrax::ValkyrieWorkCreator.new(title: ['My Work'])
result = generator.create

# Check if creation was successful
if result.success?
  puts "Work created: #{generator.resource.id}"
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

### Relationships

Add works to collections or add works to collections:
```ruby
Skullrax::ValkyrieWorkCreator.new(
  member_of_collection_ids: ['collection-123']
).create
```

The collection must exist before adding works to it. If the collection is not found, a `Skullrax::CollectionNotFoundError` will be raised.

You can also add collections as members of other collections:
```ruby
Skullrax::ValkyrieCollectionCreator.new(
  member_of_collection_ids: ['parent-collection-123']
).create
```

Adding a work as a child work:
```ruby
Skullrax::ValkyrieWorkCreator.new(
  member_ids: ['child-work-123']
).create
```

The works must exist before adding them to a collection. If any work is not found, a `Skullrax::WorkNotFoundError` will be raised.

## Collection Creation

Skullrax can also create collections with the same ease and flexibility as works.

### Basic Collection Creation

Create a collection with all required fields populated:
```ruby
Skullrax::ValkyrieCollectionCreator.new.create
```

### Customized Collection Creation

Specify your own attributes:
```ruby
Skullrax::ValkyrieCollectionCreator.new(
  title: 'Custom Collection Title',
  creator: 'Jane Doe',
  visibility: 'authenticated'
).create
```

### Custom IDs

Specify custom IDs for works and collections instead of auto-generated ones:

#### Custom Work ID
```ruby
Skullrax::ValkyrieWorkCreator.new(
  id: 'custom-work-id-123',
).create
```

#### Custom Collection ID
```ruby
Skullrax::ValkyrieCollectionCreator.new(
  id: 'custom-collection-id-456',
).create
```

**Important:** The ID must be unique. If an object with that ID already exists, a `Skullrax::IdAlreadyExistsError` will be raised.

**Use cases for custom IDs:**
- Maintaining consistent IDs across environments
- Migrating content from another system
- Creating predictable URLs for testing
- Integrating with external systems that reference specific IDs

### Auto-fill with Exclusions

Use `autofill: true` to populate all settable properties, with optional exclusions:
```ruby
Skullrax::ValkyrieCollectionCreator.new(
  autofill: true,
  except: :hide_from_catalog_search,
  visibility: 'open'
).create
```

### Collection Features

Collections support the same features as works:
- **Auto-fill Mode**: Use `autofill: true` to populate all settable properties
- **Property Exclusions**: Use `except:` to skip specific fields
- **Controlled Vocabularies**: Automatically validated against Questioning Authority
- **Visibility Settings**: Including embargoes and leases
- **Geonames Integration**: Automatic location URI lookup

**Note:** Collections use the default collection type. They do not support file attachments (use works for that).

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
