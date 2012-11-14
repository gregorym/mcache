# encoding: utf-8
module MCache
  
  module ClassMethods
    def write_version(index_by, record)
      current_version = Rails.cache.read(record_version_key(index_by, record)) || 0
      Rails.cache.write(record_version_key(index_by, record), current_version + 1)
    end

    def write_record(index_by, record)
      Rails.cache.write record_key(index_by), record
    end

    def read_record(index_by, record)
      Rails.cache.read record_key(index_by, record)
    end

    private
      def record_key(index_by, record)
        current_version = record_version_key(index_by)
        (prefix_key + [record.send(:index_by).to_s, current_version]).join('_')
      end

      def record_version_key(index_by)
        (prefix_key + [index_by.to_s]).join('_')
      end

      def prefix_key
        ['mcache', self.table_name]
      end
  end

  module InstanceMethods
    def write_changes
      index_by = @m_cache_options[:index_by]
        
      self.class.write_version(index_by, self)
      self.class.write_record(index_by, self)
      true
    end
  end

  module ActiveRecordExtension
    def m_cache(*opts)
      extend  MCache::ClassMethods
      include MCache::InstanceMethods

      @m_cache_options = opts.pop.symbolize_keys.slice(:index_by)

      define_method "find_by_#{@m_cache_options[:index_by]}".to_sym do |id|
        record = read_record(@m_cache_options[:index_by])
        if record.present?
          record
        else
          record = super(id)
          if record.present?
            write_changes
          end
          record
        end
      end

      after_commit :write_changes
    end
  end
end

ActiveRecord::Base.send(:extend,  MCache::ActiveRecordExtension)