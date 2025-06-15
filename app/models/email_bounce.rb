=begin
mysql> desc email_bounces;
+--------------+--------------+------+-----+---------+----------------+
| Field        | Type         | Null | Key | Default | Extra          |
+--------------+--------------+------+-----+---------+----------------+
| id           | bigint       | NO   | PRI | NULL    | auto_increment |
| email        | varchar(160) | YES  | MUL | NULL    |                |
| subject      | varchar(120) | YES  |     | NULL    |                |
| delivered_at | timestamp    | YES  | MUL | NULL    |                |
| reason       | text         | YES  |     | NULL    |                |
+--------------+--------------+------+-----+---------+----------------+
=end
class EmailBounce < ApplicationRecord
  
end
