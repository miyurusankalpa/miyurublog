<?php

$files = glob('posts/2019/*.{md}', GLOB_BRACE);
foreach($files as $file) {
	
  echo "<a href=\"posts.php?file=".$file."\">".$file."</a><br>";
}


?>