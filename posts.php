<?php
$filepath = $_GET['file'];
$filename = basename($filepath, ".md");

include 'Parsedown.php';

$Parsedown = new Parsedown();

$text = file_get_contents($filepath);

$content = Parsedown::instance()
   ->setBreaksEnabled(true) # enables automatic line breaks
   ->text($text);
   
preg_match("'<h1>(.*?)</h1>'si", $content, $match);
if($match) $title = $match[1]; else $title = "miyuru blog";


// Start the buffering //
ob_start();
?>
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" CONTENT="text/html; charset=utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?php echo $title; ?></title>
<style>
    body {
        max-width: 90ex;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
		margin-top: 30px;
    }
	code {
		display: block;
		overflow-x: auto;
		padding: 0.5em;
		background: #333;
		color: white;
	}
}
</style>
</head>
<body>
<a href="https://blog.miyuru.lk">home</a>
<?php
echo $content;
?>
<hr>
<p style="text-align:right;">By Miyuru <br>Page generated on <?php echo date('d M Y',time()); ?></p>
<img src="https://www.miyuru.lk/Buffy.php?idsite=3&amp;rec=1" style="border:0" alt="" />
</body>
</html>
<?php
// Get the content that is in the buffer and put it in your file //
file_put_contents("static/".$filename.".html", ob_get_contents());
?>