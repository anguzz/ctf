<?php
    try {
        $phar = new Phar('polyglot.phar'); 
        $phar->extractTo('./extracted_phar_contents');
        echo "Files extracted to ./extracted_phar_contents\n";
    } catch (Exception $e) {
        echo "Error: " . $e->getMessage() . "\n";
        echo "Make sure 'phar.readonly' is set to 'Off' in your php.ini, or run with 'php -d phar.readonly=0 extract_phar.php'\n";
    }
?>