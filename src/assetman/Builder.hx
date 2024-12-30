package assetman;

import assetman.ninja.Builder as NinjaBuilder;
import assetman.ninja.EdgeBuilder as NinjaEdgeBuilder;
import assetman.ninja.RuleBuilder as NinjaRuleBuilder;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
import hx.files.Dir;
using StringTools;
using hx.strings.Strings;

private typedef PostBuilder = {
    var builder: BuilderInterface;
    var compiler: (NinjaBuilder, Dynamic, Array<String>, String)->Array<String>;
}

private typedef Params = {
    var ninja : NinjaBuilder;
    var srcPath: String;
    var postBuilders: Array<PostBuilder>;
    var srcPatterns: Map<Pattern, Bool>;
    var outputs: Array<String>;
}

abstract class Builder {

    var ninja : NinjaBuilder;
    var rules : Array<RuleBuilder> = [];
    var singles : Array<SingleBuilder> = [];
    var bundles : Array<BundleBuilder> = [];

    public function new() {
        ninja = new NinjaBuilder();
    }

    // Assemble Util rules in ninja
    function setupUtilRules(ninja : NinjaBuilder, srcPath : String) {
        // Setup rule for building file list file
        var compareEchoPath = hx.files.Path.of(Sys.programPath()).parent.getAbsolutePath() + '/compare_echo.n';
        compareEchoPath = compareEchoPath.replace(" ", "$ ").replace(":", "$:");
        var command = 'neko ' + compareEchoPath + ' "$$glob" $$out $$path';
        ninja.rule('COMPARE_ECHO')
        .restat(true)
        .generator(true)
        .description('Updating file list...')
        .run(command);
        // Setup rule for generating build.ninja
#if neko
        var command = 'neko ${Sys.programPath()} ${srcPath}';
#else
#error Unsupported platform
#end
        ninja.rule('GENERATE')
        .generator(true)
        .description('Re-running assetman...')
        .run(command);
    };

    // Loop through assign object keys and values and
    // assign them as variables on edge
    function edgeAssign(edge : NinjaEdgeBuilder, assign:Map<String, String>) {
        for(key => value in assign) {
            edge.assign(key, value);
        }
    };

    // Loop over RuleBuilders and generate ninja rules
    function compileRules(ninja : NinjaBuilder, rules: Array<RuleBuilder>) {
        for(rule in rules) {
            ninja.rule(rule._name).run(rule._command);
        }
    };

    // Loop over edge builder class, compile list of files that match the pattern
    // and call the compile callback.
    // Edges that are build relative are a special condition and only work on files
    // that are outputs of other build statements.
    // These edgeBuilders are saved for later
    function compileEdges(edgeBuilders : Array<BuilderInterface>, params : Params, compileBuilder:(NinjaBuilder, BuilderInterface, Array<String>, String)->Array<String>) {
        for(edgeBuilder in edgeBuilders) {
            if(edgeBuilder.buildRelative) {
                params.postBuilders.push({
                    builder: edgeBuilder,
                    compiler: compileBuilder
                });
                continue;
            }

            if(!StringTools.endsWith(params.srcPath, "/")) {
                params.srcPath += '/';
            }

            params.srcPatterns[edgeBuilder.pattern] = true;

            var search_root_path : String;
            var file_pattern : EReg;
            switch( edgeBuilder.pattern ) {
                case Glob( pattern ):
                    search_root_path = params.srcPath + pattern.substringBefore("*").substringBeforeLast("/");
                    file_pattern = hx.files.GlobPatterns.toEReg(pattern);

                case RegEx( base_directory, pattern ):
                    search_root_path = params.srcPath + '/' + base_directory;
                    file_pattern = new EReg( StringTools.replace( params.srcPath, '/', '\\/') + pattern, "" );
            }

            var excludes_regexp = edgeBuilder.excludes.map( function(pattern){
                switch( pattern ) {
                    case Glob( pattern ):
                        return hx.files.GlobPatterns.toEReg(pattern);

                    case RegEx( base_directory, pattern ):
                        return new EReg( StringTools.replace( params.srcPath, '/', '\\/') + pattern, "" );
                }
            } );

            final search_root_offset = params.srcPath.endsWith("/") ? params.srcPath.length8() : params.srcPath.length8() + 1;
            var hx_files = [];
            Dir.of(search_root_path).walk(
               function(file) {
                  var file_path = file.path.toString().substr8(search_root_offset);
                  if (file_pattern.match(file_path)) {
                    for(exclude in excludes_regexp) {
                        if(exclude.match(file_path))
                        {
                            return;
                        }
                    }
                    hx_files.push(file);
                  }
               },
               function(dir) {
                  return true;
               }
            );
            var files = hx_files.map(
            function(a) {
                return relativePath(FileSystem.absolutePath(params.srcPath), a.path.getAbsolutePath());
            });

            var outputs = compileBuilder(params.ninja, edgeBuilder, files, params.srcPath);
            params.outputs = params.outputs.concat(outputs);
        }
    };

    // Loop over build relative builders. Match the patterns to the files that the
    // other edges produce.
    function compilePostBuilders(params : Params) {
        var postOutputs = [];

        for(post in params.postBuilders) {
            var pattern : EReg;

            switch( post.builder.pattern) {
                case Glob(glob_pattern): pattern = hx.files.GlobPatterns.toEReg(glob_pattern);
                case RegEx(base, regex_pattern ): pattern = new EReg( regex_pattern, "" );
            }

            var files = params.outputs.filter(function(output) {
                return pattern.match(output);
            });

            // do no create edge if there are no input files
            if(files.length == 0) {
                return;
            }

            var outputs = post.compiler(params.ninja, post.builder, files, '.');
            postOutputs = postOutputs.concat(outputs);
        }

        params.outputs = params.outputs.concat(postOutputs);
    };

    // Generates eges for file
    function compileSingle(ninja : NinjaBuilder, _single : BuilderInterface, files : Array<String>, srcPath: String) {
        var outputs  : Array<String> = [];
        var single = cast(_single, SingleBuilder);

        for(file in files) {

            var parent = hx.files.Path.of(file).parent;

            var relative_directory = parent != null ? relativePath(FileSystem.absolutePath(""), parent.getAbsolutePath()) : "";

            var input_path = Path.join([srcPath, file])
                .replace(" ", "$ ")
                .replace(":", "$:");
            var filepath = hx.files.Path.of(file);
            var filename = filepath.filenameStem;

            var directory = hx.files.Path.of(filepath.getAbsolutePath()).parent.getAbsolutePath();
            var relative_filepath =  Path.join([relative_directory, filename]);
            var filename_without_extension = directory + '/' + filename;

            var output_paths = single.targets.map(function(a) {
                return a
                    .replace("$filename_without_extension", filename_without_extension)
                    .replace("$filename", filename)
                    .replace("$filepath", relative_filepath)
                    .replace("$directory", directory)
                    .replace(" ", "$ ")
                    .replace(":", "$:");
                });

            var assignments = new Map();

            for(key => value in single.assignments) {
                assignments[ key ] =
                    value.replace("$filename_without_extension", filename_without_extension)
                        .replace("$filepath", relative_filepath)
                        .replace("$filename", filename)
                        .replace("$directory", directory);
            }

            var edge = ninja.edge(output_paths);
            edge.from(input_path).usingRule(single.rule);
            edgeAssign(edge, assignments);
            outputs = outputs.concat(output_paths);
        }

        return outputs;
    };

    // generates an edge for all files
    function compileBundle(ninja : NinjaBuilder, _bundle : BuilderInterface, files : Array<String>, srcPath: String) {
        var bundle = cast(_bundle, BundleBuilder);

        if(!bundle.buildRelative) {
            files = files.map(function(file) {
                return Path.join([srcPath, file]);
            });
        }

        if(bundle.targets.length == 0) {
            trace('WARN: No targets specified for bundle clause with pattern: ' + bundle.pattern);
            return null;
        }

        var edge = ninja.edge(bundle.targets);
        edge.from(files).usingRule(bundle.rule);
        edgeAssign(edge, bundle.assignments);
        return bundle.targets;
    };

    // Generate file list edge that watches path 'path' and generates file 'filename'
    function generateGlobLists(ninja : NinjaBuilder, filename: String, patternMap: Map<Pattern, Bool>, path : String) {
        var patternList = [ for(key=>value in patternMap) key];

        if(patternList.length > 0) {
            var globs = patternList.join(' ');

            ninja.edge([filename])
            .from('.dirty')
            .assign('glob', globs)
            .assign('path', path)
            .usingRule('COMPARE_ECHO');
            return true;
        }

        return false;
    };


    function rule(arg:String) {
        var obj = new RuleBuilder(arg);
        rules.push(obj);
        return obj;
    }

    overload extern inline function single(baseDirectory : String, regex : String) {
        var obj = new SingleBuilder(RegEx(baseDirectory, regex));
        singles.push(obj);
        return obj;
    }

    overload extern inline function single(arg:String) {
        var obj = new SingleBuilder(Glob(arg));
        singles.push(obj);
        return obj;
    }

    function bundle(arg:String) {
        var obj = new BundleBuilder(Glob(arg));
        bundles.push(obj);
        return obj;
    }

    // Main generate function
    public function generate(srcPath : String) {
        if(srcPath != null && srcPath != '.') {
            srcPath = relativePath(FileSystem.absolutePath(""), srcPath);
        } else {
            srcPath = '.';
        }

        if(!StringTools.endsWith(srcPath, '/')) {
            srcPath = srcPath + '/';
        }

        var generatorPath = Sys.programPath();
        setupUtilRules(ninja, srcPath);
        configure();
        // stores lists of patterns to check
        var params : Params = {
            ninja: ninja,
            srcPath: srcPath,
            postBuilders: [],
            srcPatterns: new Map(),
            outputs: []
        };
        compileRules(ninja, rules);
        compileEdges(singles.map(function(a) {return cast a;}), params, compileSingle);
        compileEdges(bundles.map(function(a) {return cast a;}), params, compileBundle);
        // generate edges that rely on outputs of other edges
        compilePostBuilders(params);
        /************************************************
         * Util edges
         */
        ninja.edge(['.dirty']);
        var srcFileList = '.src_files';
        // generate glob watcher for patterns in the soruce dir
        generateGlobLists(ninja, srcFileList, params.srcPatterns, srcPath);
        generatorPath = generatorPath.replace(" ", "$ ").replace(":", "$:");
        // ninja generator command
        ninja.edge(['build.ninja'])
        .from([generatorPath, srcFileList])
        .usingRule('GENERATE');
        ninja.byDefault(params.outputs.join(' '));
        ninja.save('build.ninja');
    };

    abstract function configure() : Void;


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