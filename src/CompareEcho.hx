
import sys.FileSystem;
import hx.files.Dir;
import haxe.io.Path;

class CompareEcho {


    static function main() {
        var args = Sys.args();
        var current_directory : String;

        if(args.length >= 3) {
            current_directory = args[2];
        } else {
            current_directory = FileSystem.absolutePath("");
        }

        // construct search patterns
        var patterns = args[0].split(' ').map(function(a) {return a;});
        var pattern = patterns.length > 1 ? '{' + patterns.join(',') + '}' : patterns[0];
        // collect files that match pattern
        var dir = Dir.of(current_directory);
        var files = dir.findFiles(pattern).map(
        function(a) {
            return relativePath(FileSystem.absolutePath(current_directory), a.path.getAbsolutePath());
        });
        files.sort(Reflect.compare);
        var files_as_text = files.join('\n');
        // update file list in output if they don't match
        var outpath = args[1];
        var write_file : Bool = true;

        if(sys.FileSystem.exists(outpath)) {
            var oldfiles = sys.io.File.getContent(outpath);
            write_file = oldfiles != files_as_text;
        }

        if(write_file) {
            sys.io.File.saveContent(outpath, files_as_text);
        }
    }

    static function relativePath(relativeTo: String, path: String) {
        // make both absolute
        path = Path.removeTrailingSlashes(FileSystem.absolutePath(path));
        relativeTo = Path.removeTrailingSlashes(FileSystem.absolutePath(relativeTo));
        var aPath = path.split('/');
        var aRelativeTo = relativeTo.split('/');
        // find shared part of path
        var matchesUpToIndex = 0;

        for(i in 0...aRelativeTo.length) {
            if(aPath[i] == aRelativeTo[i]) {
                matchesUpToIndex = i;
            } else {
                break;
            }
        }

        return [for(_ in 0...(aRelativeTo.length - 1) - matchesUpToIndex) '..']
               .concat(aPath.slice(matchesUpToIndex + 1))
               .join('/');
    }
}