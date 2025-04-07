require "base64"
require "digest"

ANSWERS = %w[
  ST-HELLO
  ST-CONST
  ST-IVAR
  RI-CLASS
  RI-STONE
  RI-ENCODED
  ML-GOOD
  DT-FIXME
  ST-IRB
  RE-🐾💎🐾
  IR-HISTORY
]

puts "Answers:"
ANSWERS.each do |answer|
  puts Digest::SHA256.hexdigest(answer)
end

puts "\nBase64:"
puts "base64(RI-ENCODED): #{Base64.encode64("RI-ENCODED")}"

class MLang
  def initialize(code)
    @code = code
  end

  def run
    insns = @code.scan(/../)
    pc = 0
    mem = 0
    output = ""
    while pc < insns.size
      insn = insns[pc]
      op = insn[0]
      n = insn[1].to_i(36)
      case op
      when "+"
        mem += n
      when "-"
        mem -= n
      when "."
        n.times { output << mem.chr }
      end
      pc += 1
    end
    output
  end
end

puts "\nMLang results:"
%w[
  +z+z+2.1-3.1+7.2+3.1
  +z+z+7.1-1.1-v.1+q.1+8.2-b.1
].each do |code|
  puts "#{code} => #{MLang.new(code).run}"
end

