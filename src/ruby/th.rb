require "irb"
require "irb/context"

require "base64"
require "digest"
require "singleton"

FONT_STYLE = {
  bold: "1",
  yellow: "33",
  link: "1;4;34",
}

def font(style, text)
  "\e[#{FONT_STYLE[style]}m#{text}\e[m"
end

def bold(text)
  font :bold, text
end

def wasm?
  RUBY_PLATFORM.start_with?("wasm")
end

class TreasureHunt
  include Singleton

  module IrbCommand
    class ThCommand < IRB::Command::Base
      def th
        TreasureHunt.instance
      end
    end

    class Th < ThCommand
      category "TreasureHunt"
      description "Show your TreasureHunt status."

      def execute(arg)
        th.list_treasures
      end
    end

    class Capture < ThCommand
      category "TreasureHunt"
      description "Capture found treasure."

      def execute(arg)
        treasure =  /^['"]?([^"']+)['"]?$/.match(arg) && Regexp.last_match[1]
        if !treasure
          puts "usage: th-capture TREASURE-CODE"
        elsif TREASURE_DIGESTS.include?(Digest::SHA256.hexdigest(treasure))
          puts "You got a treasure! #{bold treasure}"
          (th.treasures << treasure).uniq!
          th.save!
          puts
          th.list_treasures
        else
          puts "#{bold treasure} is not valid treasure!"
        end
      end
    end

    class Hint < ThCommand
      category "TreasureHunt"
      description "Show TreasureHunt hint."

      def execute(arg)
        TreasureHunt.instance.hint_count += 1

        if arg.chomp == "--more"
          case TreasureHunt.instance.hint_count % 3
          when 0
            puts <<~EOM
              #{font(:link, "TreasureDetector")}#{bold ".nop"} is not implemented.
              You can define it in IRB.
            EOM
          when 1
            puts "`cd #{font :link, "River"}` move IRB workspace into #{font :link, "River"} class."
          when 2
            puts "`ls #{font :link, "River"}` shows #{font :link, "River"} class internal."
          end
        else
          case TreasureHunt.instance.hint_count % 4
          when 0
            puts "#{bold "th-hint"} can use with --more option."
          when 1
            puts "See #{bold "ls"} output..."
          when 2
            puts "This game provided by #{bold "______"}."
          when 3
            puts "The treasure is in the #{ font :link, "River" }..."
          end
        end
      end
    end

    class Detector < ThCommand
      category "TreasureHunt"
      description "Treasure detector."

      def execute(arg)
        if arg.chomp == "--use"
          puts TreasureDetector.new.use
        else
          puts "You can find treasure by #{bold "th-detector"} command: th-detector --use"
        end
      end
    end
  end

  TREASURE_DIGESTS = %w[
    7866f0727e9b5017fd27ec70c9a53d767297ee29cc68772675480fa668639fce
    d8d8641046ae4c61c149f5d555c2b7de26b9bbb61414fb2c2fc2c7eaae3fd7f8
    e203aef6f792772055446a6ff66568e9c8f42d6b3106131ab4a37366fc10b540
    2b9ce33a393394d9e7a57674727a80210015de9616c679a6b8120078754a4aa4
    692e7d1ce99f2e11c6ae93328676bb561610377bc6c4b5c27ccf5922abf2e2ef
    a13fdfad17025bca589e1df8e6659758f547ae08b9d2785defd2d22520baf444
    40d5a8cebc645c340df2a0d4ac62c0ad1dd0b3d9a9aa61e14a55b56ed7d7a5e6
    02decd2dfce70d2e0cf81bd753582c8d8a94c4a8c1b7297949e38dc5280e1b46
  ]

  attr_accessor :hint_count
  attr_reader :treasures

  def initialize
    require "js" if wasm?

    load!
    @hint_count = 0
    puts <<~EOM
      Welcome to TreasureHunt game on IRB.
      You can use many IRB features for explorering treasure.

      There are many useful IRB commands:
        #{bold "help"} Shows IRB commands.
        #{bold "ls"} Shows methods, constatns and variables in current workspace.
        #{bold "cd"} Changes current workspace.
        ...

      You could find some TreasureHunt commands with #{bold "help"} command.
      If you found treasure, please use #{bold "th-capture"} command: th-capture TREASURE-CODE

      At first, try: puts \"Hello, STORES\"
    EOM
  end

  def save!
    if wasm?
      JS.global[:localStorage].setItem("treasures", @treasures.join(","))
    else
      File.write("/tmp/th-treasures", @treasures.join(","))
    end
  end

  def load!
    if wasm?
      val = JS.global[:localStorage].getItem("treasures")
      @treasures = val.typeof == "string" ? val.to_s.split(",") : []
    else
      @treasures = File.exist?("/tmp/th-treasures") ? File.read("/tmp/th-treasures").split(",") : []
    end
  end

  def list_treasures
    if treasures.size == 0
      puts "You have no treasures."
    else
      puts "You have #{bold treasures.size} treasures:"
      treasures.each do |treasure|
        puts "- #{bold treasure}"
      end
    end
  end
end

IRB::Command.register("th", TreasureHunt::IrbCommand::Th)
IRB::Command.register("th-capture", TreasureHunt::IrbCommand::Capture)
IRB::Command.register("th-hint", TreasureHunt::IrbCommand::Hint)
IRB::Command.register("th-detector", TreasureHunt::IrbCommand::Detector)

# Initialize TreasureHunt
TreasureHunt.instance

puts_method = method(:puts)
Kernel.define_method(:puts) do |*args|
  if args[0] == "Hello, STORES"
    puts_method.call(font(:yellow, <<~EOM))
      You found a treasure!: ST-HELLO

      You can use th-capture command to capture this treasure: th-capture ST-HELLO
    EOM
  end
  puts_method.call(*args)
end

STORES = font(:yellow, "You found a treasure!: ST-CONST")
@stores = font(:yellow, "You found a treasure!: ST-IVAR")

class River
  class << self
    def treasure
      font(:yellow, "You found a treasure!: RI-CLASS")
    end

    def hooks
      @hooks
    end

    def register(event_type, hook)
      @hooks ||= {}
      @hooks[event_type] ||=  []
      @hooks[event_type] << hook
    end

    def trigger(event_type)
      return unless @hooks && @hooks[event_type]
      @hooks[event_type].each do |hook|
        hook.call
      end
    end

    def encoded
      font(:yellow, "You found a encoded treasure: UkktRU5DT0RFRA==")
    end

    def bottom
      <<~EOM
        A stone #{font(:link, "Tablet")} is at the bottom of the river.
        It has some writing on it.
        Let's call #{font(:link, "Tablet.read")}.
      EOM
    end
  end
end

River.register(:explore, -> { puts font(:yellow, "You found a treasure!: RI-STONE") })

class Tablet
  class << self
    def read
      puts <<~EOM
        The tablet says:
        You can get the treasure by running program: #{bold "+z+z+7.1-1.1-v.1+q.1+8.2-b.1"}.
        To learn how to run it, read #{font(:link, "Tablet")}#{bold ".interpreter"}
      EOM
    end

    def interpreter
      puts <<~EOM
        The interpreter could run programs like these.

        #{bold "Interpreter:"}
        - Interpreter has a single memory
        - At first, the memory is 0
        - The interpreter reads the program from left to right

        #{bold "Instruction:"}
        - Each instruction is 2 characters long
        - The first character is an operator
          - #{bold "+"}: memory += n
          - #{bold "-"}: memory -= n
          - #{bold "."}: print memory.chr n times
        - The second character is a number
          - Numbers are in base 36 (0-9, a-z)

        #{bold "Example:"}
        - +z+z+2.1-3.1+7.2+3.1 => HELLO
      EOM
    end
  end
end

class TreasureDetector
  def self.hint
    puts <<~EOM
      #{font(:link, "TreasureDetector")}#{bold ".nop"} is not implemented.
      You can define it in IRB.
    EOM
  end

  def use
    nop
    puts "You got a treasure! #{bold "DT-FIXME"}"
  end
end

irbrc = wasm? ? "#{ENV["HOME"]}/.irbrc" : ".irbrc"

File.write(irbrc, <<~RUBY)
  require "irb/color_printer"
  IRB::Inspector.def_inspector([:th]) do |v|
    output = StringIO.new
    if v.to_s.include?("\e")
      output.print(v.to_s)
    else
      IRB::ColorPrinter.pp(v, output)
    end
    output.string.chomp
  end
  IRB.conf[:INSPECT_MODE] = :th
RUBY

IRB.start if __FILE__ == $0
