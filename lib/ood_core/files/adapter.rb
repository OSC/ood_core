# frozen_string_literal: true

module OodCore
  module Files
    # Adapter for access to files on a cluster, for the dashboard's file browser, transfers and interactive apps.
    #
    # Paths are absolute paths on the cluster, as a String or Pathname. Methods raise if the operation failed.
    # Progress blocks are yielded an Integer percentage (0-100) whenever it changes.
    class Adapter
      def initialize(*); end

      # @return [Pathname] where interactive app sessions and other dashboard data are staged on the cluster
      def dataroot
        raise NotImplementedError, 'files adapter did not define #dataroot'
      end

      # @param path [String, Pathname]
      # @return [Boolean] whether path is a directory, following symlinks; raises if path does not exist
      def directory?(path)
        raise NotImplementedError, 'files adapter did not define #directory?'
      end

      # @param path [String, Pathname]
      # @return [Boolean] whether path exists, following symlinks
      def exist?(path)
        raise NotImplementedError, 'files adapter did not define #exist?'
      end

      # The entries of a directory, without . and .., following symlinks.
      # @param path [String, Pathname] the directory
      # @return [Array<Hash>] one Hash per entry with :name [String], :size [Integer, nil] (bytes, nil for
      #   directories), :directory [Boolean], :date [Integer] (modification time, seconds since the epoch),
      #   :owner [String] and :mode [Integer] (permission bits)
      def ls(path)
        raise NotImplementedError, 'files adapter did not define #ls'
      end

      # All files under a directory, to download it as a zip. Symlinks to files are included, but symlinks to
      # directories are not followed.
      # @param path [String, Pathname] the directory
      # @return [Array<String>] absolute paths of the files
      def ls_recursive(path)
        raise NotImplementedError, 'files adapter did not define #ls_recursive'
      end

      # @param path [String, Pathname]
      # @return [Boolean] whether path is a regular file the user can both read and write
      def editable?(path)
        raise NotImplementedError, 'files adapter did not define #editable?'
      end

      # @param path [String, Pathname]
      # @return [Boolean] whether the user can read path, following symlinks; raises if this could not be checked
      def readable?(path)
        raise NotImplementedError, 'files adapter did not define #readable?'
      end

      # @param path [String, Pathname] the file
      # @yieldparam chunk [String] the next part of the content, if a block is given
      # @return [String] the content, if no block is given
      def read(path, &block)
        raise NotImplementedError, 'files adapter did not define #read'
      end

      # Creates an empty file, or updates its modification time if it exists.
      # @param path [String, Pathname]
      def touch(path)
        raise NotImplementedError, 'files adapter did not define #touch'
      end

      # Creates a directory and any missing parents. Does nothing if it already exists.
      # @param path [String, Pathname]
      def mkdir(path)
        raise NotImplementedError, 'files adapter did not define #mkdir'
      end

      # Writes content to path, creating missing parent directories. A new file is created like any other new file on
      # the file system, and an existing file only has its content replaced.
      # @param path [String, Pathname] the file
      # @param content [String, IO] the content, or an IO to read it from
      # @yieldparam percent [Integer] written so far, only if the size of content is known
      def write(path, content, &block)
        raise NotImplementedError, 'files adapter did not define #write'
      end

      # @param path [String, Pathname] the file
      # @return [Integer] its size in bytes, following symlinks
      def size(path)
        raise NotImplementedError, 'files adapter did not define #size'
      end

      # @param path [String, Pathname] the directory
      # @param timeout [Integer] seconds to wait for the result
      # @return [Integer] total size in bytes of the directory and everything in it, following symlinks
      # @raise [Timeout::Error] if this takes longer than timeout
      def directory_size(path, timeout:)
        raise NotImplementedError, 'files adapter did not define #directory_size'
      end

      # @param path [String, Pathname] the file
      # @return [String] its MIME type as reported by the cluster, e.g. "text/plain" or "inode/x-empty"
      def mime_type(path)
        raise NotImplementedError, 'files adapter did not define #mime_type'
      end

      # Moves src to dst, which can be on this cluster or the local filesystem.
      # @param src_fs [OodCore::Cluster, nil] the cluster src is on, or nil for the local filesystem
      # @param dest_fs [OodCore::Cluster, nil] the cluster dst is on, or nil for the local filesystem
      # @param src [String, Pathname]
      # @param dst [String, Pathname]
      # @yieldparam percent [Integer] done so far
      def move_with_progress(src_fs, dest_fs, src, dst, &block)
        raise NotImplementedError, 'files adapter did not define #move_with_progress'
      end

      # Copies src to dst, which can be on this cluster or the local filesystem. Parameters as for #move_with_progress.
      # @yieldparam percent [Integer] done so far
      def copy_with_progress(src_fs, dest_fs, src, dst, &block)
        raise NotImplementedError, 'files adapter did not define #copy_with_progress'
      end

      # Removes path, recursively if it is a directory.
      # @param path [String, Pathname]
      # @yieldparam percent [Integer] done so far
      def remove_with_progress(path, &block)
        raise NotImplementedError, 'files adapter did not define #remove_with_progress'
      end
    end
  end
end
