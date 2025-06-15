module Ioffer::EncryptionHelper


  def self.included(base)

    base.extend ClassMethods
  end

  module ClassMethods

    @@encryption_key = nil

    def encrypt(text)
      cipher = cipher_method.encrypt
      cipher.key = fetch_encryption_key
      s = cipher.update(text) + cipher.final
  
      s.unpack('H*')[0].upcase
    end
  
    def decrypt(text)
      cipher = cipher_method.decrypt
      cipher.key = fetch_encryption_key
      s = [text].pack('H*').unpack('C*').pack('c*')
  
      cipher.update(s) + cipher.final
    end
  
  
    def cipher_method
      OpenSSL::Cipher.new('DES-EDE3-CBC')
    end
  
    ##
    # Find key in order: @@encryption_key, inside ENV['USER_ENCRYPTION_KEY'], file shared/user_encryption_key.txt, file db/user_encryption_key.txt.
    # If key not found, would set the class variable and save to file in shared folder.
    def fetch_encryption_key
      unless @@encryption_key
        should_save_to_file = false
        key_file_name = 'user_encryption.key'
        shared_path = File.join( Rails.root.to_s.gsub(/(\/current)\Z/i, ''), 'shared' )
        shared_file_path = File.join(shared_path, key_file_name)
  
        @@encryption_key = ENV['USER_ENCRYPTION_KEY']
        if @@encryption_key.blank?
          should_save_to_file = true
        end
  
        if @@encryption_key.blank?
          # In shared folder
          if File.exists?(shared_file_path)
            @@encryption_key = File.open(shared_file_path, 'r:BINARY').read.strip
          end
        end
  
        if @@encryption_key.blank?
          # In db folder
          db_file_path = File.join(Rails.root, 'db', key_file_name)
          if File.exists?(db_file_path)
            @@encryption_key = File.open(db_file_path, 'r:BINARY').read.strip
          end
        end
  
        @@encryption_key = cipher_method.random_key if @@encryption_key.blank?
  
        if should_save_to_file
          FileUtils.mkdir_p( shared_path )
          File.open(shared_file_path, 'w:BINARY'){|io| io.write @@encryption_key.force_encoding('BINARY') }
        end
      end
      @@encryption_key
    end
  end
end