# frozen_string_literal: true

RSpec.describe Skullrax::ParamsToCsvConverterService do
  describe '#to_csv' do
    context 'with a simple GenericWork' do
      let(:params) do
        {
          'resource-0' => {
            'type' => 'GenericWork',
            'admin_set_id' => 'admin_set_default',
            'title' => ['No Collection Work 1 Title'],
            'creator' => ['No Collection Work 1 Creator', 'Second Creator'],
            'visibility' => 'open'
          }
        }
      end

      it 'converts to CSV format' do
        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility
          GenericWorkResource,admin_set_default,No Collection Work 1 Title,No Collection Work 1 Creator;Second Creator,open
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(1)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
      end
    end

    context 'with a simple Collection' do
      let(:params) do
        {
          'resource-0' => {
            'type' => 'CollectionResource',
            'title' => ['Collection 1 Title'],
            'creator' => ['Collection 1 Creator'],
            'visibility' => 'open'
          }
        }
      end

      it 'converts to CSV format' do
        expected_csv = <<~CSV
          model,title,creator,visibility
          CollectionResource,Collection 1 Title,Collection 1 Creator,open
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(1)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
      end
    end

    context 'with a Collection containing a work' do
      let(:params) do
        {
          'resource-0' => {
            'type' => 'CollectionResource',
            'title' => ['Collection 1 Title'],
            'creator' => ['Collection 1 Creator'],
            'visibility' => 'open',
            'works' => {
              'work-1' => {
                'type' => 'GenericWork',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Collection 1 Work 1 Title'],
                'creator' => ['Collection 1 Work 1 Creator'],
                'visibility' => 'open'
              }
            }
          }
        }
      end

      it 'converts to CSV with collection first, then work' do
        expected_csv = <<~CSV
          model,title,creator,visibility,admin_set_id
          CollectionResource,Collection 1 Title,Collection 1 Creator,open,
          GenericWorkResource,Collection 1 Work 1 Title,Collection 1 Work 1 Creator,open,admin_set_default
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(2)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
        expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
      end
    end

    context 'with a collection containing multiple works' do
      let(:params) do
        {
          'resource-0' => {
            'type' => 'CollectionResource',
            'title' => ['Collection 1 Title'],
            'creator' => ['Collection 1 Creator'],
            'visibility' => 'open',
            'works' => {
              'work-1' => {
                'type' => 'GenericWork',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Work 1 Title'],
                'creator' => ['Work 1 Creator'],
                'visibility' => 'open'
              },
              'work-2' => {
                'type' => 'GenericWork',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Work 2 Title'],
                'creator' => ['Work 2 Creator'],
                'visibility' => 'restricted'
              }
            }
          }
        }
      end

      it 'converts to CSV with collection, then both works' do
        expected_csv = <<~CSV
          model,title,creator,visibility,admin_set_id
          CollectionResource,Collection 1 Title,Collection 1 Creator,open,
          GenericWorkResource,Work 1 Title,Work 1 Creator,open,admin_set_default
          GenericWorkResource,Work 2 Title,Work 2 Creator,restricted,admin_set_default
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(3)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
        expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
        expect(actual_rows[2].to_h).to eq(expected_rows[2].to_h)
      end
    end

    context 'with a work containing files array' do
      let(:file1) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png') }
      let(:file2) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.txt') }
      let(:uploaded_file1) { double('UploadedFile', tempfile: double(path: file1.to_s)) }
      let(:uploaded_file2) { double('UploadedFile', tempfile: double(path: file2.to_s)) }

      let(:params) do
        {
          'resource-0' => {
            'type' => 'GenericWork',
            'admin_set_id' => 'admin_set_default',
            'title' => ['Work with Files'],
            'creator' => ['Work Creator'],
            'visibility' => 'open',
            'files' => [uploaded_file1, uploaded_file2]
          }
        }
      end

      it 'converts to CSV with files joined by semicolon' do
        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility,file
          GenericWorkResource,admin_set_default,Work with Files,Work Creator,open,#{file1};#{file2}
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(1)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
      end
    end

    context 'with a work containing remote_files array' do
      let(:params) do
        {
          'resource-0' => {
            'type' => 'GenericWork',
            'admin_set_id' => 'admin_set_default',
            'title' => ['Work with Remote Files'],
            'creator' => ['Work Creator'],
            'visibility' => 'open',
            'remote_files' => ['https://example.com/file1.jpg', 'https://example.com/file2.pdf']
          }
        }
      end

      it 'converts to CSV with remote files joined by semicolon' do
        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility,file
          GenericWorkResource,admin_set_default,Work with Remote Files,Work Creator,open,https://example.com/file1.jpg;https://example.com/file2.pdf
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(1)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
      end
    end

    context 'with a work containing both local files and remote files' do
      let(:file1) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png') }
      let(:uploaded_file1) { double('UploadedFile', tempfile: double(path: file1.to_s)) }

      let(:params) do
        {
          'resource-0' => {
            'type' => 'GenericWork',
            'admin_set_id' => 'admin_set_default',
            'title' => ['Work with Mixed Files'],
            'creator' => ['Work Creator'],
            'visibility' => 'open',
            'files' => [uploaded_file1],
            'remote_files' => ['https://example.com/image.jpg']
          }
        }
      end

      it 'converts to CSV with both local and remote files joined by semicolon' do
        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility,file
          GenericWorkResource,admin_set_default,Work with Mixed Files,Work Creator,open,#{file1};https://example.com/image.jpg
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(1)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
      end
    end

    context 'with a collection containing a work with a fileset' do
      let(:file1) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png') }
      let(:uploaded_file) { double('UploadedFile', tempfile: double(path: file1.to_s)) }

      let(:params) do
        {
          'resource-0' => {
            'type' => 'CollectionResource',
            'title' => ['Collection 1 Title'],
            'creator' => ['Collection 1 Creator'],
            'visibility' => 'open',
            'works' => {
              'work-1' => {
                'type' => 'GenericWork',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Work with FileSet'],
                'creator' => ['Work Creator'],
                'visibility' => 'open',
                'filesets' => {
                  'fileset-1' => {
                    'type' => 'Hyrax::FileSet',
                    'title' => ['FileSet Title'],
                    'creator' => ['FileSet Creator'],
                    'visibility' => 'open',
                    'file' => uploaded_file
                  }
                }
              }
            }
          }
        }
      end

      it 'converts to CSV with collection, work, then fileset' do
        expected_csv = <<~CSV
          model,title,creator,visibility,admin_set_id,file
          CollectionResource,Collection 1 Title,Collection 1 Creator,open,,
          GenericWorkResource,Work with FileSet,Work Creator,open,admin_set_default,
          Hyrax::FileSet,FileSet Title,FileSet Creator,open,,#{file1}
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(3)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
        expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
        expect(actual_rows[2].to_h).to eq(expected_rows[2].to_h)
      end
    end

    context 'with a collection containing a work with multiple local filesets' do
      let(:file1) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png') }
      let(:file2) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.txt') }
      let(:uploaded_file1) { double('UploadedFile', tempfile: double(path: file1.to_s)) }
      let(:uploaded_file2) { double('UploadedFile', tempfile: double(path: file2.to_s)) }

      let(:params) do
        {
          'resource-0' => {
            'type' => 'CollectionResource',
            'title' => ['Collection 1 Title'],
            'creator' => ['Collection 1 Creator'],
            'visibility' => 'open',
            'works' => {
              'work-1' => {
                'type' => 'GenericWork',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Work with Multiple FileSets'],
                'creator' => ['Work Creator'],
                'visibility' => 'open',
                'filesets' => {
                  'fileset-1' => {
                    'type' => 'Hyrax::FileSet',
                    'title' => ['FileSet 1 Title'],
                    'creator' => ['FileSet 1 Creator'],
                    'visibility' => 'open',
                    'file' => uploaded_file1
                  },
                  'fileset-2' => {
                    'type' => 'Hyrax::FileSet',
                    'title' => ['FileSet 2 Title'],
                    'creator' => ['FileSet 2 Creator'],
                    'visibility' => 'restricted',
                    'file' => uploaded_file2
                  }
                }
              }
            }
          }
        }
      end

      it 'converts to CSV with collection, work, then both filesets' do
        expected_csv = <<~CSV
          model,title,creator,visibility,admin_set_id,file
          CollectionResource,Collection 1 Title,Collection 1 Creator,open,,
          GenericWorkResource,Work with Multiple FileSets,Work Creator,open,admin_set_default,
          Hyrax::FileSet,FileSet 1 Title,FileSet 1 Creator,open,,#{file1}
          Hyrax::FileSet,FileSet 2 Title,FileSet 2 Creator,restricted,,#{file2}
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(4)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
        expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
        expect(actual_rows[2].to_h).to eq(expected_rows[2].to_h)
        expect(actual_rows[3].to_h).to eq(expected_rows[3].to_h)
      end
    end

    context 'with a collection containing a work with mixed local and remote filesets' do
      let(:file1) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png') }
      let(:uploaded_file1) { double('UploadedFile', tempfile: double(path: file1.to_s)) }

      let(:params) do
        {
          'resource-0' => {
            'type' => 'CollectionResource',
            'title' => ['Collection 1 Title'],
            'creator' => ['Collection 1 Creator'],
            'visibility' => 'open',
            'works' => {
              'work-1' => {
                'type' => 'GenericWork',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Work with Mixed FileSets'],
                'creator' => ['Work Creator'],
                'visibility' => 'open',
                'filesets' => {
                  'fileset-1' => {
                    'type' => 'Hyrax::FileSet',
                    'title' => ['Local FileSet Title'],
                    'creator' => ['FileSet Creator'],
                    'visibility' => 'open',
                    'file' => uploaded_file1
                  },
                  'fileset-2' => {
                    'type' => 'Hyrax::FileSet',
                    'title' => ['Remote FileSet Title'],
                    'creator' => ['FileSet Creator'],
                    'visibility' => 'open',
                    'remote_file' => 'https://example.com/image.jpg'
                  }
                }
              }
            }
          }
        }
      end

      it 'converts to CSV with collection, work, then both filesets' do
        expected_csv = <<~CSV
          model,title,creator,visibility,admin_set_id,file
          CollectionResource,Collection 1 Title,Collection 1 Creator,open,,
          GenericWorkResource,Work with Mixed FileSets,Work Creator,open,admin_set_default,
          Hyrax::FileSet,Local FileSet Title,FileSet Creator,open,,#{file1}
          Hyrax::FileSet,Remote FileSet Title,FileSet Creator,open,,https://example.com/image.jpg
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(4)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
        expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
        expect(actual_rows[2].to_h).to eq(expected_rows[2].to_h)
        expect(actual_rows[3].to_h).to eq(expected_rows[3].to_h)
      end
    end

    context 'with a collection containing a work with multiple remote filesets' do
      let(:params) do
        {
          'resource-0' => {
            'type' => 'CollectionResource',
            'title' => ['Collection 1 Title'],
            'creator' => ['Collection 1 Creator'],
            'visibility' => 'open',
            'works' => {
              'work-1' => {
                'type' => 'GenericWork',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Work with Remote FileSets'],
                'creator' => ['Work Creator'],
                'visibility' => 'open',
                'filesets' => {
                  'fileset-1' => {
                    'type' => 'Hyrax::FileSet',
                    'title' => ['Remote FileSet 1 Title'],
                    'creator' => ['FileSet Creator'],
                    'visibility' => 'open',
                    'remote_file' => 'https://example.com/image1.jpg'
                  },
                  'fileset-2' => {
                    'type' => 'Hyrax::FileSet',
                    'title' => ['Remote FileSet 2 Title'],
                    'creator' => ['FileSet Creator'],
                    'visibility' => 'restricted',
                    'remote_file' => 'https://example.com/image2.pdf'
                  }
                }
              }
            }
          }
        }
      end

      it 'converts to CSV with collection, work, then both remote filesets' do
        expected_csv = <<~CSV
          model,title,creator,visibility,admin_set_id,file
          CollectionResource,Collection 1 Title,Collection 1 Creator,open,,
          GenericWorkResource,Work with Remote FileSets,Work Creator,open,admin_set_default,
          Hyrax::FileSet,Remote FileSet 1 Title,FileSet Creator,open,,https://example.com/image1.jpg
          Hyrax::FileSet,Remote FileSet 2 Title,FileSet Creator,restricted,,https://example.com/image2.pdf
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(4)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
        expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
        expect(actual_rows[2].to_h).to eq(expected_rows[2].to_h)
        expect(actual_rows[3].to_h).to eq(expected_rows[3].to_h)
      end
    end

    context 'with standalone work and collection in params (wrong order)' do
      let(:params) do
        {
          'resource-0' => {
            'type' => 'CollectionResource',
            'title' => ['Collection Title'],
            'creator' => ['Collection Creator'],
            'visibility' => 'open',
            'works' => {
              'work-1' => {
                'type' => 'GenericWork',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Work in Collection'],
                'creator' => ['Work Creator'],
                'visibility' => 'open'
              }
            }
          },
          'resource-1' => {
            'type' => 'GenericWork',
            'admin_set_id' => 'admin_set_default',
            'title' => ['Standalone Work'],
            'creator' => ['Standalone Creator'],
            'visibility' => 'open'
          }
        }
      end

      it 'outputs CSV with standalone work first, then collection and its works' do
        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility
          GenericWorkResource,admin_set_default,Standalone Work,Standalone Creator,open
          CollectionResource,,Collection Title,Collection Creator,open
          GenericWorkResource,admin_set_default,Work in Collection,Work Creator,open
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(3)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
        expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
        expect(actual_rows[2].to_h).to eq(expected_rows[2].to_h)
      end
    end

    context 'with standalone work with fileset and collection with work with fileset (wrong order)' do
      let(:file1) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png') }
      let(:file2) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.txt') }
      let(:uploaded_file1) { double('UploadedFile', tempfile: double(path: file1.to_s)) }
      let(:uploaded_file2) { double('UploadedFile', tempfile: double(path: file2.to_s)) }

      let(:params) do
        {
          'resource-0' => {
            'type' => 'CollectionResource',
            'title' => ['Collection Title'],
            'creator' => ['Collection Creator'],
            'visibility' => 'open',
            'works' => {
              'work-1' => {
                'type' => 'GenericWork',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Work in Collection'],
                'creator' => ['Work Creator'],
                'visibility' => 'open',
                'filesets' => {
                  'fileset-2' => {
                    'type' => 'Hyrax::FileSet',
                    'title' => ['Collection Work FileSet'],
                    'creator' => ['FileSet Creator'],
                    'visibility' => 'open',
                    'file' => uploaded_file1
                  }
                }
              }
            }
          },
          'resource-3' => {
            'type' => 'GenericWork',
            'admin_set_id' => 'admin_set_default',
            'title' => ['Standalone Work'],
            'creator' => ['Standalone Creator'],
            'visibility' => 'open',
            'filesets' => {
              'fileset-4' => {
                'type' => 'Hyrax::FileSet',
                'title' => ['Standalone Work FileSet'],
                'creator' => ['FileSet Creator'],
                'visibility' => 'open',
                'file' => uploaded_file2
              }
            }
          }
        }
      end

      it 'outputs CSV with standalone work and its fileset first, then collection with work and its fileset' do
        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility,file
          GenericWorkResource,admin_set_default,Standalone Work,Standalone Creator,open,
          Hyrax::FileSet,,Standalone Work FileSet,FileSet Creator,open,#{file2}
          CollectionResource,,Collection Title,Collection Creator,open,
          GenericWorkResource,admin_set_default,Work in Collection,Work Creator,open,
          Hyrax::FileSet,,Collection Work FileSet,FileSet Creator,open,#{file1}
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(5)
        expect(actual_rows[0].to_h).to eq(expected_rows[0].to_h)
        expect(actual_rows[1].to_h).to eq(expected_rows[1].to_h)
        expect(actual_rows[2].to_h).to eq(expected_rows[2].to_h)
        expect(actual_rows[3].to_h).to eq(expected_rows[3].to_h)
        expect(actual_rows[4].to_h).to eq(expected_rows[4].to_h)
      end
    end

    context 'with multiple standalone works and multiple collections all with filesets (wrong order)' do
      let(:file1) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png') }
      let(:file2) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.txt') }
      let(:uploaded_file1) { double('UploadedFile', tempfile: double(path: file1.to_s)) }
      let(:uploaded_file2) { double('UploadedFile', tempfile: double(path: file2.to_s)) }

      let(:params) do
        {
          'resource-0' => {
            'type' => 'CollectionResource',
            'title' => ['Collection 1 Title'],
            'creator' => ['Collection 1 Creator'],
            'visibility' => 'open',
            'works' => {
              'work-1' => {
                'type' => 'GenericWork',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Collection 1 Work'],
                'creator' => ['Work Creator'],
                'visibility' => 'open',
                'filesets' => {
                  'fileset-2' => {
                    'type' => 'Hyrax::FileSet',
                    'title' => ['Collection 1 FileSet'],
                    'creator' => ['FileSet Creator'],
                    'visibility' => 'open',
                    'file' => uploaded_file1
                  }
                }
              }
            }
          },
          'resource-3' => {
            'type' => 'GenericWork',
            'admin_set_id' => 'admin_set_default',
            'title' => ['Standalone Work 1'],
            'creator' => ['Standalone Creator 1'],
            'visibility' => 'open',
            'filesets' => {
              'fileset-4' => {
                'type' => 'Hyrax::FileSet',
                'title' => ['Standalone 1 FileSet'],
                'creator' => ['FileSet Creator'],
                'visibility' => 'open',
                'file' => uploaded_file2
              }
            }
          },
          'resource-5' => {
            'type' => 'CollectionResource',
            'title' => ['Collection 2 Title'],
            'creator' => ['Collection 2 Creator'],
            'visibility' => 'restricted',
            'works' => {
              'work-6' => {
                'type' => 'GenericWork',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Collection 2 Work'],
                'creator' => ['Work Creator'],
                'visibility' => 'open',
                'filesets' => {
                  'fileset-7' => {
                    'type' => 'Hyrax::FileSet',
                    'title' => ['Collection 2 FileSet'],
                    'creator' => ['FileSet Creator'],
                    'visibility' => 'open',
                    'remote_file' => 'https://example.com/file.jpg'
                  }
                }
              }
            }
          },
          'resource-8' => {
            'type' => 'GenericWork',
            'admin_set_id' => 'admin_set_default',
            'title' => ['Standalone Work 2'],
            'creator' => ['Standalone Creator 2'],
            'visibility' => 'restricted',
            'filesets' => {
              'fileset-9' => {
                'type' => 'Hyrax::FileSet',
                'title' => ['Standalone 2 FileSet'],
                'creator' => ['FileSet Creator'],
                'visibility' => 'restricted',
                'remote_file' => 'https://example.com/file2.pdf'
              }
            }
          }
        }
      end

      it 'outputs CSV with all standalone works first, then all collections' do
        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility,file
          GenericWorkResource,admin_set_default,Standalone Work 1,Standalone Creator 1,open,
          Hyrax::FileSet,,Standalone 1 FileSet,FileSet Creator,open,#{file2}
          GenericWorkResource,admin_set_default,Standalone Work 2,Standalone Creator 2,restricted,
          Hyrax::FileSet,,Standalone 2 FileSet,FileSet Creator,restricted,https://example.com/file2.pdf
          CollectionResource,,Collection 1 Title,Collection 1 Creator,open,
          GenericWorkResource,admin_set_default,Collection 1 Work,Work Creator,open,
          Hyrax::FileSet,,Collection 1 FileSet,FileSet Creator,open,#{file1}
          CollectionResource,,Collection 2 Title,Collection 2 Creator,restricted,
          GenericWorkResource,admin_set_default,Collection 2 Work,Work Creator,open,
          Hyrax::FileSet,,Collection 2 FileSet,FileSet Creator,open,https://example.com/file.jpg
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(10)
        (0..9).each do |i|
          expect(actual_rows[i].to_h).to eq(expected_rows[i].to_h)
        end
      end
    end

    context 'with full complex real-world params structure' do
      let(:file1) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.png') }
      let(:file2) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.txt') }
      let(:file3) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file.csv') }
      let(:file4) { Skullrax.root.join('spec', 'fixtures', 'files', 'test_file2.csv') }
      let(:uploaded_file1) { double('UploadedFile', tempfile: double(path: file1.to_s)) }
      let(:uploaded_file2) { double('UploadedFile', tempfile: double(path: file2.to_s)) }
      let(:uploaded_file3) { double('UploadedFile', tempfile: double(path: file3.to_s)) }
      let(:uploaded_file4) { double('UploadedFile', tempfile: double(path: file4.to_s)) }

      let(:params) do
        {
          'resource-0' => {
            'type' => 'CollectionResource',
            'title' => ['Collection 1 Title'],
            'creator' => ['Collection 1 Creator 2', 'Collection 1 Creator 2'],
            'visibility' => 'open',
            'works' => {
              'work-4' => {
                'type' => 'GenericWork',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Collection 1 Work 1 Title'],
                'creator' => ['Collection 1 Work 1 Creator'],
                'visibility' => 'open',
                'files' => [uploaded_file1],
                'filesets' => {
                  'fileset-6' => {
                    'type' => 'Hyrax::FileSet',
                    'title' => ['Collection 1 Work FileSet Form Title'],
                    'creator' => ['Collection 1 Work FileSet Form Creator'],
                    'visibility' => 'restricted',
                    'remote_file' => 'https://example.com/image.jpg'
                  }
                }
              },
              'work-5' => {
                'type' => 'Monograph',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Collection 1 Work 2 Title'],
                'creator' => ['Collection 1 Work 2 Creator'],
                'record_info' => ['Collection 1 Work 2 Record Info'],
                'visibility' => 'restricted'
              }
            }
          },
          'resource-1' => {
            'type' => 'GenericWork',
            'admin_set_id' => 'admin_set_default',
            'title' => ['No Collection Work 1 Title'],
            'creator' => ['No Collection Work 1 Creator'],
            'visibility' => 'embargo',
            'visibility_during_embargo' => 'restricted',
            'embargo_release_date' => '2026-01-30',
            'visibility_after_embargo' => 'authenticated',
            'remote_files' => ['https://example.com/image2.jpg', 'https://example.com/image3.jpg'],
            'filesets' => {
              'fileset-2' => {
                'type' => 'Hyrax::FileSet',
                'title' => ['No Collection Work 1 FileSet Form Title'],
                'creator' => ['No Collection Work 1 FileSet Form Title'],
                'visibility' => 'open',
                'file' => uploaded_file2
              }
            }
          },
          'resource-3' => {
            'type' => 'Monograph',
            'admin_set_id' => 'admin_set_default',
            'title' => ['No Collection Work 2 Title'],
            'creator' => ['No Collection Work 2 Creator'],
            'record_info' => ['No Collection Work 2 Record Info'],
            'visibility' => 'open'
          },
          'resource-7' => {
            'type' => 'CollectionResource',
            'title' => ['Collection 2 Title'],
            'creator' => ['Collection 2 Creator'],
            'visibility' => 'restricted',
            'works' => {
              'work-8' => {
                'type' => 'GenericWork',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Collection 2 Work 1 Title'],
                'creator' => ['Collection 2 Work 1 Creator'],
                'subject' => ['Collection 2 Work 1 Subject 1', 'Collection 2 Work 1 Subject 2'],
                'visibility' => 'lease',
                'visibility_during_lease' => 'open',
                'lease_expiration_date' => '2026-01-30',
                'visibility_after_lease' => 'restricted',
                'files' => [uploaded_file3, uploaded_file4]
              },
              'work-10' => {
                'type' => 'Monograph',
                'admin_set_id' => 'admin_set_default',
                'title' => ['Collection 2 Work 2 Title'],
                'creator' => ['Collection 2 Work 2 Creator'],
                'record_info' => ['Collection 2 Work 2 Record info'],
                'visibility' => 'restricted',
                'filesets' => {
                  'fileset-11' => {
                    'type' => 'Hyrax::FileSet',
                    'title' => ['Collection 2 Work 2 FileSet Form 1 Title'],
                    'creator' => ['Collection 2 Work 2 FileSet Form 1 Creator'],
                    'license' => ['http://creativecommons.org/publicdomain/zero/1.0/'],
                    'visibility' => 'open',
                    'file' => uploaded_file2
                  },
                  'fileset-12' => {
                    'type' => 'Hyrax::FileSet',
                    'title' => ['Collection 2 Work 2 FileSet Form 2 Title'],
                    'creator' => ['Collection 2 Work 2 FileSet Form 2 Creator'],
                    'visibility' => 'authenticated',
                    'remote_file' => 'https://example.com/image4.jpg'
                  }
                }
              }
            }
          }
        }
      end

      it 'handles full complex nested structure with proper ordering' do
        expected_csv = <<~CSV
          model,admin_set_id,title,creator,visibility,visibility_during_embargo,embargo_release_date,visibility_after_embargo,record_info,subject,visibility_during_lease,lease_expiration_date,visibility_after_lease,license,file
          GenericWorkResource,admin_set_default,No Collection Work 1 Title,No Collection Work 1 Creator,embargo,restricted,2026-01-30,authenticated,,,,,,,https://example.com/image2.jpg;https://example.com/image3.jpg
          Hyrax::FileSet,,No Collection Work 1 FileSet Form Title,No Collection Work 1 FileSet Form Title,open,,,,,,,,,,#{file2}
          Monograph,admin_set_default,No Collection Work 2 Title,No Collection Work 2 Creator,open,,,,No Collection Work 2 Record Info,,,,,,
          CollectionResource,,Collection 1 Title,Collection 1 Creator 2;Collection 1 Creator 2,open,,,,,,,,,,
          GenericWorkResource,admin_set_default,Collection 1 Work 1 Title,Collection 1 Work 1 Creator,open,,,,,,,,,,#{file1}
          Hyrax::FileSet,,Collection 1 Work FileSet Form Title,Collection 1 Work FileSet Form Creator,restricted,,,,,,,,,,https://example.com/image.jpg
          Monograph,admin_set_default,Collection 1 Work 2 Title,Collection 1 Work 2 Creator,restricted,,,,Collection 1 Work 2 Record Info,,,,,,
          CollectionResource,,Collection 2 Title,Collection 2 Creator,restricted,,,,,,,,,,
          GenericWorkResource,admin_set_default,Collection 2 Work 1 Title,Collection 2 Work 1 Creator,lease,,,,,Collection 2 Work 1 Subject 1;Collection 2 Work 1 Subject 2,open,2026-01-30,restricted,,#{file3};#{file4}
          Monograph,admin_set_default,Collection 2 Work 2 Title,Collection 2 Work 2 Creator,restricted,,,,Collection 2 Work 2 Record info,,,,,,
          Hyrax::FileSet,,Collection 2 Work 2 FileSet Form 1 Title,Collection 2 Work 2 FileSet Form 1 Creator,open,,,,,,,,,http://creativecommons.org/publicdomain/zero/1.0/,#{file2}
          Hyrax::FileSet,,Collection 2 Work 2 FileSet Form 2 Title,Collection 2 Work 2 FileSet Form 2 Creator,authenticated,,,,,,,,,,https://example.com/image4.jpg
        CSV

        service = described_class.new(params:)
        actual_csv = service.to_csv

        actual_rows = CSV.parse(actual_csv, headers: true)
        expected_rows = CSV.parse(expected_csv, headers: true)

        expect(actual_rows.length).to eq(12)
        (0..11).each do |i|
          expect(actual_rows[i].to_h).to eq(expected_rows[i].to_h)
        end
      end
    end
  end
end
