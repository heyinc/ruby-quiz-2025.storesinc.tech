require "base64"
require "digest"

ANSWERS = %w[
  ST-HELLO
  ST-CONST
  ST-IVAR
  RI-CLASS
  RI-STONE
  RI-ENCODED
]

puts "Answers:"
ANSWERS.each do |answer|
  puts Digest::SHA256.hexdigest(answer)
end

puts
puts "base64(RI-ENCODED): #{Base64.encode64("RI-ENCODED")}"
