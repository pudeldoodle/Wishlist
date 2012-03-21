<?php
// Copyright 2004-present Facebook. All Rights Reserved.

// Enforce https on production
if ($_SERVER['HTTP_X_FORWARDED_PROTO'] == "http" && $_SERVER['REMOTE_ADDR'] != '127.0.0.1') {
  header("Location: https://" . $_SERVER["HTTP_HOST"] . $_SERVER["REQUEST_URI"]);
  exit();
}

  // Process incoming image
  if (isset($_FILES["source"])) {
    if ($_FILES["source"]["error"] > 0) {
      // Show errors
      echo "Error during upload: " . $_FILES["source"]["error"];
    } else {

      // Get the image from the temporary location
      $img_path = realpath($_FILES['source']['tmp_name']);
      $img_file_prefix = basename($_FILES['source']['name']) . '_';
      //$img_file_name = uniqid($img_file_prefix).".jpg";
      $img_file_name = uniqid(). '.jpg';
      $target_path = dirname(__FILE__) . '/images/' . $img_file_name;
      $image_url = 'http://growing-leaf-2900.herokuapp.com/images/' . $img_file_name; 
      if (move_uploaded_file($img_path, $target_path)) {
      	$return_image['image_name'] =  $img_file_name;
      	$return_image['image_url'] = 'http://growing-leaf-2900.herokuapp.com/images/' . $img_file_name;
      	echo json_encode($return_image);
      } else {
        echo "ERROR: There was an error uploading the file, please try again!";
      }

    }
  }


