USE voltora;

ALTER TABLE products
  ADD COLUMN image_urls JSON NULL AFTER image_url;

UPDATE products
SET image_urls = JSON_ARRAY(image_url)
WHERE image_url IS NOT NULL AND image_url <> '';
