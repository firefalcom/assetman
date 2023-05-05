
import assetman.Builder;

class CustomBuilder extends Builder {
    public function new() {
        super();
    }

    function configure() {
        rule('convert2').command("cp $in $out");
        rule('convert').command("cp $in $out");
        rule('atlas').command("cat $in > $name.png");
        var pattern = '**/*.png';
        // build foo@2x.png: convert2 ../src/foo.psd
        single(pattern).to("$filename@2x.png").usingRule('convert2');
        // build foo.png: convert ../src/foo.psd
        single(pattern).toExt('.png').usingRule('convert');
        var atlasName = 'atlas';
        // build atlas.png atlas.csv: atlas foo.png foo@2x.png
        //     name = atlas
        bundle('images/*.png')
            .fromBuild(true)
            .to([atlasName + '.png'])
            .assign('name', atlasName)
            .usingRule('atlas');
    }
}

class Main {


    static function main() {
        var builder = new CustomBuilder();
        builder.generate("../test");
    }
}