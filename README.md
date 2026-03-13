# Skullrax

An easy programmatic way to create Valkyrie works in Hyrax 5 based applications for use in development. Skullrax provides a simple, Rails console approach to work creation with automatic field population.

## Features

- **Simple Resource Creation**: Create works and collections with minimal configuration
- **Two Creation Modes**: Use `generate` for development (auto-fills fields) or `create` for non-Development (explicit values only)
- **Intelligent Defaults**: Automatically fills required fields with placeholder data in generate mode
- **Auto-fill Mode**: Optionally populate all settable properties, not just required ones
- **Flexible Property Control**: Exclude specific properties from being set
- **Controlled Vocabulary Support**: Intelligently handles Questioning Authority vocabularies
- **Geonames Integration**: Automatically looks up location URIs from plain text queries
- **File Attachment**: Support for local and remote file uploads
- **File Set Metadata**: Set individual metadata for each attached file
- **Visibility Management**: Configure visibility including embargoes and leases
- **CSV Batch Operations**: Import, update, or delete multiple resources at once via CSV
- **Hyku Compatible**: Handles Hyku's authority naming quirks (e.g., `audience.yml` vs `audiences.yml`)
- **Error Handling**: Comprehensive error tracking for debugging
- **MCP Server**: Optional AI-driven CRUD via Model Context Protocol (Claude Desktop, Claude.ai)

## Installation

Add this line to your Hyrax application's Gemfile:
```ruby
gem 'skullrax', github: 'kirkkwang/skullrax', branch: 'main'
```

And then execute:
```bash
bundle install
rails generate skullrax:install
```

## Configuration

Skullrax can be configured in an initializer (e.g. `config/initializers/skullrax.rb`):

```ruby
Skullrax.configure do |config|
  # Override the global default used for any property not covered by a more specific rule.
  # Receives the model name and property name as positional arguments (both strings).
  config.default_test_value = ->(model, property) { "#{model} #{property}" }

  # Register a callable for a specific model + property combination.
  # Use the model name as a string to avoid load order issues.
  config.test_default_for('GenericWorkResource', :video_embed) do |_model, _property|
    'https://www.youtube.com/embed/Znf73dsFdC8'
  end

  # Register a model-level default (no property) — applies to any property on that model
  # not covered by a more specific registration.
  config.test_default_for('GenericWorkResource') do |model, property|
    "Test #{property} for #{model}"
  end
end
```

### Callable interface

All callables (the global `default_test_value` and any `test_default_for` blocks) receive two positional arguments:

| Argument | Type | Value |
|---|---|---|
| `model` | String | The model class name, e.g. `"GenericWorkResource"` |
| `property` | String | The property name, e.g. `"title"` |

### Lookup priority

When Skullrax needs a test value for a given model and property, it checks in this order:

1. A per-model+property registration: `config.test_default_for(MyModel, :my_property)`
2. A model-level default: `config.test_default_for(MyModel)`
3. The global `default_test_value` (built-in default: `"Test #{property}"`)

---

## Usage

### Two Creation Modes

Skullrax offers two methods for creating resources:

**`generate`** - Development mode that auto-fills required fields
```ruby
Skullrax::ValkyrieWorkGenerator.new(title: ['My Work']).generate
# Auto-fills required fields like creator with "Test creator"
```

**`create`** - Non-Development mode that only uses what you provide
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  title: ['My Work'],
  creator: ['Jane Doe']
).create
# Fails if required fields are missing
```

### Basic Work Generation

Generate a work with all required fields automatically populated:
```ruby
Skullrax::ValkyrieWorkGenerator.new.generate
```

### Auto-fill All Settable Properties

Use `autofill: true` to populate all settable properties, not just required ones:
```ruby
Skullrax::ValkyrieWorkGenerator.new.generate(autofill: true)
```

### Excluding Properties

Exclude specific properties from being set using `except:`:
```ruby
# Exclude a single property
Skullrax::ValkyrieWorkGenerator.new.generate(autofill: true, except: :video_embed)

# Exclude multiple properties
Skullrax::ValkyrieWorkGenerator.new.generate(autofill: true, except: [:based_near, :subject])
```

### Generate Without Auto-filling Required Fields

If you want to generate but not auto-fill required fields:
```ruby
Skullrax::ValkyrieWorkGenerator.new(title: ['My Work']).generate(fill_required: false)
# Only uses the title you provided, doesn't fill other required fields
```

### Customized Work Creation

Specify your own attributes for both modes:
```ruby
# Generate mode - fills in missing required fields
Skullrax::ValkyrieWorkGenerator.new(
  model: Monograph,
  title: ['Sample Work Title'],
  keyword: ['sample', 'work', 'keywords'],
  visibility: 'open'
).generate

# Create mode - strict, only uses what you provide
Skullrax::ValkyrieWorkGenerator.new(
  model: Monograph,
  title: ['Sample Work Title'],
  creator: ['Author Name'],
  keyword: ['sample', 'work', 'keywords'],
  visibility: 'open'
).create
```

### Active Fedora Support

Skullrax can work with legacy Active Fedora models, automatically converting them to Valkyrie resources:
```ruby
Skullrax::ActiveFedoraWorkGenerator.new(model: GenericWork).generate
# Creates a GenericWorkResource
```

### Visibility Settings

Control work visibility including embargoes and leases:

#### Basic Visibility

Set simple visibility levels (defaults to `restricted` if not specified):
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  visibility: 'open'  # or 'authenticated', 'restricted'
).generate
```

#### Embargo

Restrict access until a future date, then change to a different visibility:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  visibility: 'embargo',
  visibility_during_embargo: 'restricted',
  embargo_release_date: Date.today + 6.months,
  visibility_after_embargo: 'open'
).generate
```

#### Lease

Make work openly available for a limited time, then restrict access:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  visibility: 'lease',
  visibility_during_lease: 'open',
  lease_expiration_date: '2030-12-31',  # Date or String accepted
  visibility_after_lease: 'authenticated'
).generate
```

**Note:** Both `embargo_release_date` and `lease_expiration_date` accept either `Date` objects or date strings - Hyrax forms will handle the conversion automatically.

### Geonames Location Lookup

Skullrax can automatically look up Geonames URIs from plain text location queries:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  based_near: 'San Diego'
).generate
# Automatically resolves to: https://sws.geonames.org/5391811/
```

You can also use exact URIs if you prefer:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  based_near: 'https://sws.geonames.org/5391811/'
).generate
```

**Note**: Geonames lookup requires a username. Set the `GEONAMES_USERNAME` environment variable or it defaults to 'scientist' for testing.

### Attaching Files

#### Single Local File
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  file_paths: '/path/to/file.png'
).generate
```

#### Multiple Files (Local and Remote)
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  file_paths: [
    '/path/on/disk/local-image.jpg',
    '/path/to/another/file.txt'
  ]
).generate
```

#### Remote Files

Download and attach files from URLs:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  file_paths: 'https://example.com/path/to/remote-image.jpg'
).generate
```

#### Mixed Local and Remote Files
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  file_paths: [
    'https://example.com/path/to/remote-image.jpg',
    'path/on/disk/local-image.jpg'
  ]
).generate
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
).generate
```

The order of `file_set_params` corresponds to the order of `file_paths`.

#### Single File Set Metadata

If you provide a single hash instead of an array, it applies only to the first file:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  file_paths: ['/path/to/file1.pdf', '/path/to/file2.jpg'],
  file_set_params: { title: 'Contract Document', description: 'Legal contract' }
).generate
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
).generate
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

#### Model Flexibility

You can use either Valkyrie resource names or Active Fedora model names:
```ruby
csv = <<~CSV
  model,title,creator,visibility
  Collection,Related Collection,Collection Creator,open
  GenericWork,Work in Collection,Work Creator,open
  FileSet,My File,File Creator,open,/path/to/file.pdf
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.import
# Automatically converts: Collection → CollectionResource, GenericWork → GenericWorkResource, FileSet → Hyrax::FileSet
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
  CollectionResource,col-789,Related Collection,Collection Creator,,open
  GenericWorkResource,,Work in Collection,Work Creator,col-789,open
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
  CollectionResource,New Collection,Collection Creator,open
  GenericWorkResource,Work1 in New Collection,Work Creator,open
  GenericWorkResource,Work2 in New Collection,Work Creator,open
  CollectionResource,Another Collection,Another Creator,open
  GenericWorkResource,Work1 in Another Collection,Another Creator,open
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
  GenericWorkResource,Standalone Work1,Standalone Creator,open
  GenericWorkResource,Standalone Work2,Standalone Creator,open
  CollectionResource,New Collection,Collection Creator,open
  GenericWorkResource,Work1 in New Collection,Work Creator,open
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
  CollectionResource,New Collection,Collection Creator,open,
  GenericWorkResource,Work1 in Collection,Work Creator,open,
  FileSet,FileSet1 for Work1,FileSet Creator,open,/path/to/file1.jpg
  FileSet,FileSet2 for Work1,FileSet Creator,open,/path/to/file2.jpg
  GenericWorkResource,Work2 in Collection,Work Creator,open,
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
  GenericWorkResource,Work with Remote File,
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
  GenericWorkResource,Work with Multiple Values,Work Creator,open,History;Art;Science,sample;test;demo
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
  GenericWorkResource,Work with Subjects,Work Creator,open,History|Art|Science
CSV

importer = Skullrax::CsvImporter.new(csv:, delimiter: '|')
importer.import
```

**Note:** Delimiters only apply to fields that are defined as multi-value in your model's schema (fields with `form` metadata). Single-value fields like `title` are not split.

#### Autofill and Exclusions
You can enable auto-fill mode and exclude specific properties during CSV import:
```ruby
importer = Skullrax::CsvImporter.new(csv:)
importer.import(autofill: true, except: [:video_embed, :based_near])
```

By default, autofill is false and if the CSV does not provide required fields, work creation will fail.

#### Updating Resources via CSV

Update existing collections, works, and file sets by providing their IDs:
```ruby
csv = <<~CSV
  id,title,creator,description
  work-123,Updated Work Title,Updated Creator,New description
  collection-456,Updated Collection,Updated Creator,New description
  file-set-789,Updated File Set,Updated Creator,New description
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.update
```

**Requirements:**
- All rows must include an `id` column
- All IDs must exist in the database (error raised if any ID is not found)
- The `model` column is ignored - resources keep their existing type

**Update with Merge:**

By default, updates replace field values. Use `merge: true` to append to existing values:
```ruby
# Work currently has: subject: ['History']
csv = <<~CSV
  id,subject
  work-123,Science;Art
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.update(merge: true)
# Result: subject: ['History', 'Science', 'Art']
```

**Update with Autofill:**

Fill in empty fields with test data:
```ruby
csv = <<~CSV
  id
  work-123
  collection-456
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.update(autofill: true)
# Fills all empty fields with "Test <property>" values
```

**Update with Exclusions:**

Combine autofill with exclusions:
```ruby
importer.update(autofill: true, except: [:description, :based_near])
# Fills all fields except description and based_near
```

**Important Notes:**
- File sets are updated independently, not bundled with their parent work
- The model cannot be changed during update (a GenericWork stays a GenericWork)
- Updates preserve fields not included in the CSV

#### Deleting Resources via CSV

Bulk delete collections, works, and file sets by providing their IDs:

```ruby
csv = <<~CSV
  id
  work-123
  collection-456
  file-set-789
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.destroy
```

**Requirements:**
- All rows must include an id column
- All IDs must exist in the database (error raised if any ID is not found)

**Safe Deletion:** Skullrax automatically prioritizes deletion order (File Sets → Works → Collections) to ensure file sets are cleanly unlinked from their parents before the parents are destroyed.

#### Supported Model Types

CSV import supports:
- **Collection** or **CollectionResource** - Collections (uses `Hyrax.config.collection_class`)
- **Curation Concerns** - Any registered curation concern, using either Active Fedora or Valkyrie names (e.g., `GenericWork`/`GenericWorkResource`, `Image`/`ImageResource`, `Monograph`)
- **FileSet** or **Hyrax::FileSet** - File sets with attachments

#### CSV Column Reference

Common columns supported:
- `model` - Optional (defaults to `GenericWorkResource`). The resource type to create
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

#### Dry Run / Validation Mode

Usage example:
```ruby
csv = <<~CSV
  model,title,creator,visibility
  Collection,Dry Run Collection,Dry Run Creator,open
  GenericWork,Dry Run Work,Dry Run Creator,open
CSV

importer = Skullrax::CsvImporter.new(csv:)
importer.import(dry_run: true)
```

### CSV Export

Skullrax supports exporting existing resources into a CSV format that is fully compatible with the Importer. This enables a "Round-Trip" workflow where you can export data, edit it in your favorite spreadsheet software, and re-import it to update the resources.

#### Basic Usage

To export specific resources, pass their IDs to the exporter:

```ruby
ids = ['work-1', 'collection-2', 'file-set-3']
exporter = Skullrax::CsvExporter.new(ids:)
csv_content = exporter.export

File.write('export.csv', csv_content)
```

#### Round-Tripping (Export -> Edit -> Update)
The exported CSV contains all the necessary IDs and model types to be fed directly back into the update mode of the importer.

1. Export: Generate the CSV.
1. Edit: Modify titles, fix typos, or change visibility using the exported CSV.
1. Update: Run the importer with update.

```ruby
csv = File.read('edited_export.csv')
importer = Skullrax::CsvImporter.new(csv:)
importer.update
```

#### Exporting with Files

By default, the export only includes metadata. Note that include_files here means it will include rows for the child FileSets of any Works you export, effectively grouping them together in the CSV.

```ruby
# Exports the work AND its child file sets
exporter = Skullrax::CsvExporter.new(ids: ['work-1'])
exporter.export(include_files: true)
```

### Updating Works and Collections

Skullrax allows you to update existing works and collections by passing in the resource ID.

#### Basic Update

Update a work by replacing provided fields:
```ruby
generator = Skullrax::ValkyrieWorkGenerator.new(id: 'work-123', title: ['Updated Title'])
generator.update
# Result: title is replaced with ['Updated Title'], other fields unchanged
```

#### Update with Merge

Append to multi-value fields instead of replacing:
```ruby
# Work currently has: title: ['Original Title']
generator = Skullrax::ValkyrieWorkGenerator.new(id: 'work-123', title: ['New Title'])
generator.update(merge: true)
# Result: title: ['Original Title', 'New Title']
```

**Note:** Singular fields (like `depositor` or `admin_set_id`) are always replaced, regardless of the merge setting.

#### Update with Autofill

Fill in any empty fields with test data:
```ruby
# Work has minimal data, want to fill everything out
generator = Skullrax::ValkyrieWorkGenerator.new(id: 'work-123')
generator.update(autofill: true)
# Fills in any empty fields with "Test <property>" values
```

#### Update with Exclusions

Update while excluding specific properties:
```ruby
generator = Skullrax::ValkyrieWorkGenerator.new(id: 'work-123')
generator.update(autofill: true, except: [:description, :based_near])
# Fills all fields except description and based_near
```

#### Adding Files to Existing Works

Files are always added to works, never replaced:
```ruby
# Work has 2 existing file sets
generator = Skullrax::ValkyrieWorkGenerator.new(
  id: 'work-123',
  file_paths: '/path/to/new-file.pdf'
)
generator.update
# Result: Work now has 3 file sets (2 existing + 1 new)
```

#### Updating Collections

Collections work the same way:
```ruby
# Basic update
Skullrax::ValkyrieCollectionGenerator.new(
  id: 'collection-456',
  title: ['Updated Collection Title']
).update

# With merge
Skullrax::ValkyrieCollectionGenerator.new(
  id: 'collection-456',
  description: ['Additional description']
).update(merge: true)

# With autofill
Skullrax::ValkyrieCollectionGenerator.new(
  id: 'collection-456'
).update(autofill: true, except: :hide_from_catalog_search)
```

#### Update Behavior Summary

- **Default (replace)**: Replaces provided fields, keeps others unchanged
- **merge: true**: Appends to multi-value arrays, keeps others unchanged
- **autofill: true**: Fills empty fields after merging/replacing
- **except**: Excludes specific properties from autofill

### Deleting Works, Collections, and File Sets

Skullrax allows you to delete existing works, collections, and file sets by ID.

#### Deleting a Work

Delete a work and all its file sets:
```ruby
generator = Skullrax::ValkyrieWorkGenerator.new(id: 'work-123')
generator.destroy
```

**Note:** Deleting a work will also delete all of its associated file sets.

#### Deleting a Collection

Delete a collection:
```ruby
generator = Skullrax::ValkyrieCollectionGenerator.new(id: 'collection-456')
generator.destroy
```

**Note:** Deleting a collection will remove it from any parent collections but will not delete the works within it. The works will remain in the repository.

#### Deleting a File Set

Delete a file set from its parent work:
```ruby
generator = Skullrax::ValkyrieFileSetGenerator.new(id: 'file-set-789')
generator.destroy
```

**Note:** Deleting a file set removes it from its parent work but does not affect the work itself.

### Updating File Sets

Skullrax allows you to update metadata for existing file sets.

**Note:** File sets can only be updated, not created standalone. File sets are created as part of works using the `file_paths` parameter.

#### Basic File Set Update

Update a file set's metadata:
```ruby
generator = Skullrax::ValkyrieFileSetGenerator.new(
  id: 'file-set-123',
  title: ['Updated File Title'],
  description: ['New description']
)
generator.update
# Result: title and description are replaced
```

#### Update with Merge

Append to existing metadata values:
```ruby
# File set currently has: keyword: ['original']
generator = Skullrax::ValkyrieFileSetGenerator.new(
  id: 'file-set-123',
  keyword: ['additional']
)
generator.update(merge: true)
# Result: keyword: ['original', 'additional']
```

#### Update with Autofill

Fill in all empty metadata fields:
```ruby
generator = Skullrax::ValkyrieFileSetGenerator.new(id: 'file-set-123')
generator.update(autofill: true)
# Fills all empty fields with "Test " values
```

#### Update with Exclusions

Update while excluding specific properties:
```ruby
generator = Skullrax::ValkyrieFileSetGenerator.new(id: 'file-set-123')
generator.update(autofill: true, except: :description)
# Fills all fields except description
```

### Error Handling

Check for errors after work creation:
```ruby
creator = Skullrax::ValkyrieWorkGenerator.new(title: ['My Work'])
result = creator.generate

# Check if creation was successful
if result.success?
  puts "Work created: #{creator.resource.id}"
else
  puts "Errors: #{creator.errors}"
end
```

**Note**: Errors caught during the save process are stored in `creator.errors`. Errors that occur before save will be raised as usual.

### Relationships

Add works to collections:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  member_of_collection_ids: ['collection-123']
).generate
```

The collection must exist before adding works to it. If the collection is not found, a `Skullrax::ObjectNotFoundError` will be raised.

You can also add collections as members of other collections:
```ruby
Skullrax::ValkyrieCollectionGenerator.new(
  member_of_collection_ids: ['parent-collection-123']
).generate
```

Adding a work as a child work:
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  member_ids: ['child-work-123']
).generate
```

The works must exist before adding them to a collection. If any work is not found, a `Skullrax::ObjectNotFoundError` will be raised.

## Advanced Usage: Generators

### Dry Run / Validation Mode

All Generators (`ValkyrieWorkGenerator`, `ValkyrieCollectionGenerator`, etc.) support a `dry_run` flag.

This mode allows you to safe-test your data. It will:
1.  **Validate** all metadata against your application's forms and schemas.
2.  **Check** controlled vocabularies and constraints.
3.  **Construct** the resource in memory (populating defaults like titles or IDs).
4.  **Return** a Result object (Success/Failure) **without** persisting anything to the database.

#### Examples

**1. Validate a New Work**
Returns `Success(resource)` if valid, or `Failure(errors)` if invalid.

```ruby
generator = Skullrax::ValkyrieWorkGenerator.new(
  title: ['My Proposed Title'],
  creator: ['Doe, Jane'],
  visibility: 'open'
)

# Run with dry_run: true
result = generator.generate(dry_run: true)

if result.success?
  puts "Valid! Ready to save."
  puts "Preview: #{result.value!.title}" # => ["My Proposed Title"]
else
  warn "Validation Failed:"
  warn result.failure # => ["Resource type can't be blank", ...]
end
```

**2. safe-test an Update** Check if merging new metadata into an existing work will succeed.
```ruby
# Check if we can add a subject to an existing work
generator = Skullrax::ValkyrieWorkGenerator.new(
  id: 'existing-work-id',
  subject: ['New Subject'],
  merge: true
)

result = generator.update(dry_run: true)

# The returned resource shows what the object WOULD look like
puts result.value!.subject
# => ["Old Subject", "New Subject"]
```

**3. Safety Check a Destroy** Verifies the object exists and can be retrieved before attempting deletion.
```ruby
generator = Skullrax::ValkyrieWorkGenerator.new(id: 'work-to-delete')
result = generator.destroy(dry_run: true)

if result.success?
  puts "Object found. Ready to destroy."
else
  puts "Object not found. Destroy would have failed."
end
```

## Collection Creation

Skullrax can also create collections with the same ease and flexibility as works.

### Basic Collection Generation

Generate a collection with all required fields populated:
```ruby
Skullrax::ValkyrieCollectionGenerator.new.generate
```

### Customized Collection Creation

Specify your own attributes:
```ruby
# Generate mode
Skullrax::ValkyrieCollectionGenerator.new(
  title: 'Custom Collection Title',
  creator: 'Jane Doe',
  visibility: 'authenticated'
).generate

# Create mode (strict)
Skullrax::ValkyrieCollectionGenerator.new(
  title: 'Custom Collection Title',
  creator: 'Jane Doe',
  visibility: 'authenticated'
).create
```

### Custom IDs

Specify custom IDs for works and collections instead of auto-generated ones:

#### Custom Work ID
```ruby
Skullrax::ValkyrieWorkGenerator.new(
  id: 'custom-work-id-123'
).generate
```

#### Custom Collection ID
```ruby
Skullrax::ValkyrieCollectionGenerator.new(
  id: 'custom-collection-id-456'
).generate
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
Skullrax::ValkyrieCollectionGenerator.new(
  visibility: 'open'
).generate(autofill: true, except: :hide_from_catalog_search)
```

### Collection Features

Collections support the same features as works:
- **Two Creation Modes**: `generate` (auto-fills) and `create` (explicit)
- **Auto-fill Mode**: Use `autofill: true` to populate all settable properties
- **Property Exclusions**: Use `except:` to skip specific fields
- **Controlled Vocabularies**: Automatically validated against Questioning Authority
- **Visibility Settings**: Including embargoes and leases
- **Geonames Integration**: Automatic location URI lookup

**Note:** Collections use the default collection type. They do not support file attachments (use works for that).

## How It Works

### Automatic Field Population

Skullrax automatically (in generate mode):
- Fills missing required fields with placeholder data (e.g., "Test title")
- Detects controlled vocabulary fields using the Questioning Authority gem and selects valid values from available authority lists
- Looks up Geonames URIs when given plain text location names
- Handles special Hyrax fields like `based_near` that use nested attributes

### Generate vs Create Modes

**Generate Mode** (`generate`):
- Auto-fills required fields if not provided
- Use `autofill: true` to fill all settable properties
- Perfect for development and testing
- Creates valid resources even with minimal input

**Create Mode** (`create`):
- Only uses the attributes you explicitly provide
- Fails if required fields are missing
- Perfect for non-Development use
- Ensures you're consciously providing all necessary data

### Auto-fill Mode

When `autofill: true` is enabled in generate mode, Skullrax will populate all properties that have form metadata in the model's schema, not just required ones. This is useful for:
- Creating fully populated test works
- Exploring all available fields on a work type
- Generating sample data for development

## MCP Server

Skullrax includes an optional MCP (Model Context Protocol) server that lets AI clients like Claude Desktop or Claude.ai drive Hyrax work and collection CRUD conversationally.

### Installation

After installing Skullrax, run the MCP installer:

```bash
rails generate skullrax:mcp_install
rails db:migrate
```

This:
- Enables the MCP feature in `config/initializers/skullrax.rb`
- Installs and configures Doorkeeper for OAuth 2.1 PKCE authentication
- Injects the MCP route and OAuth discovery routes into `config/routes.rb`

### Connecting Claude Desktop

Add the MCP server to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "skullrax": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://www.example.com/skullrax/mcp"
      ]
    }
  }
}
```

On first connection, Claude Desktop will open a browser tab for OAuth login. After you authenticate with your Hyrax credentials and approve access, Claude Desktop stores the token and connects automatically on subsequent launches.

**Note:** The MCP endpoint respects all existing Hyrax CanCan permissions. If a user does not have permission to delete works in the Hyrax UI, they cannot delete works through MCP either.

### Available Tools

| Tool | Description |
|---|---|
| `get_schema` | Returns field names, types, required status, and splittable status for a work type |
| `validate_resources` | Validates records against a work type schema without persisting anything |
| `create_resources` | Creates works or collections via `ValkyrieWorkGenerator` / `ValkyrieCollectionGenerator` |
| `find_resources` | Finds resources by ID (Valkyrie query service) or Solr query string |
| `update_resources` | Updates existing works or collections by ID |
| `delete_resources` | Deletes works or collections by ID |

### Example Workflow

The tools are designed for a multi-step agentic loop where the user stays in control at the decision point:

1. User pastes a CSV or describes works they want to create
2. Claude calls `get_schema` to learn what fields are valid and required for the work type
3. Claude calls `validate_resources` to check the records — returns valid records and invalid records with reasons
4. Claude surfaces any invalid records to the user and asks how to proceed
5. User decides: create all / create only valid / abort
6. Claude calls `create_resources` to persist the approved records and reports back IDs

---

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
