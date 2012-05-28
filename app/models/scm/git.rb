module Scm
  module Git
    class << self
      def revision
        "git rev-parse --verify HEAD"
      end

      def checkout(url, code_path, branch)
        "git clone --depth 1 #{url} #{code_path} --branch #{branch}"
      end

      def update(branch)
        "git fetch && git reset --hard origin/#{branch} && git submodule update --init --recursive"
      end

      def change_list(old_rev, new_rev)
        "git whatchanged #{old_rev}..#{new_rev} --pretty=oneline --name-status"
      end

      def version(file_path)
        "git checkout #{file_path}"
      end

      def authors(versions)
        "git show  -s  --pretty=\"format:%an\"  #{versions.join('..')}| uniq| tr \"\\n\" \" \""
      end
    end
  end
end
