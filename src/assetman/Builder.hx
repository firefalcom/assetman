package assetman;

import assetman.ninja.Builder as NinjaBuilder;
import assetman.ninja.EdgeBuilder as NinjaEdgeBuilder;
import assetman.ninja.RuleBuilder as NinjaRuleBuilder;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
import hx.files.Dir;

private typedef PostBuilder = {
    var builder: BuilderInterface;
    var compiler: (NinjaBuilder, Dynamic, Array<String>, String)->Array<String>;
}

private typedef Params = {
    var ninja : NinjaBuilder;
    var srcPath: String;
    var postBuilders: Array<PostBuilder>;
    var srcPatterns: Map<String, Bool>;
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
                return;
            }

            params.srcPatterns[edgeBuilder.pattern] = true;
            var dir = Dir.of(params.srcPath);
            var files = dir.findFiles(edgeBuilder.pattern).map(
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
            var pattern =  hx.files.GlobPatterns.toEReg(post.builder.pattern);
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
        var outputs = [];
        var single = cast(_single, SingleBuilder);

        for(file in files) {
            var inputPath = Path.join([srcPath, file]);
            var filename = hx.files.Path.of(file).filenameStem;
            var outName = StringTools.replace(single.target, "$filename", filename);
            var parent = hx.files.Path.of(file).parent;
            var outputPath : String;

            if( parent != null ){
                outputPath = Path.join( [relativePath( FileSystem.absolutePath(""), parent.getAbsolutePath()), outName]);
            } else {
                outputPath = outName;
            }
            var edge = ninja.edge([outputPath]);
            edge.from(inputPath).usingRule(single.rule);
            edgeAssign(edge, single.assignments);
            outputs.push(outputPath);
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
    function generateGlobLists(ninja : NinjaBuilder, filename: String, patternMap: Map<String, Bool>, path : String) {
        var patternList = [ for(key=>value in patternMap) key];

        if(patternList.length > 0) {
            var globs = patternList.join(' ');
            trace('globs ${globs}');
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

    function single(arg:String) {
        var obj = new SingleBuilder(arg);
        singles.push(obj);
        return obj;
    }

    function bundle(arg:String) {
        var obj = new BundleBuilder(arg);
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