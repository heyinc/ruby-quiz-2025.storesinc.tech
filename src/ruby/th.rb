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
      description "Show TreasureHunt score and commands."

      def execute(arg)
        puts font(:bold, "YOUR SCORE")
        th.list_treasures

        puts font(:bold, "\nTREASURE HUNT COMMANDS")
        IRB::Command.commands.each do |name, command|
          klass = command.first
          next unless klass.category == "TreasureHunt"
          padded_name = name.to_s.ljust(10)
          puts "#{bold padded_name} - #{klass.description}"
        end
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

    class Search < ThCommand
      category "TreasureHunt"
      description "Search for treasures in the world."

      HINTS = [
        <<~EOM,
          You look around and notice a crumpled paper on the ground.
          It reads: See #{bold "ls"} output...
        EOM
        <<~EOM,
          You find a small note hidden under some leaves.
          The note reads: This game provided by #{bold "______"}
        EOM
        <<~EOM,
          You spot a worn sign on a stone.
          The sign says: The treasure is in the #{ font :link, "River" }...
        EOM
        <<~EOM,
          Near an archway, you see an instruction:
          #{bold "ls River" } shows River class internal.
        EOM
        <<~EOM,
          You notice a scribbled note on a wall:
          #{font :link, "Base64" } is useful gem bundled in Ruby.
        EOM
        <<~EOM,
          You found a big dial.
          It looks like it can run in IRB.
          The dial says:
          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
          ;;;1111111;;;$iiiiiiii;;;;;;;;;1111e1111;;:iiiiii;;;;";;;;;";;;
          ;111;;;;;;;;;;;$ii;;;;;;;;;;;;;;;1e1;;;;;:ii;;;:ii;;";";;;";";
          ;;;1111111;;;;;;$ii;;;;;false;;;;;1e1;;;;;:iiiiii;;;;";;;;;";;;
          ;;;;;;;;111;;;;;$ii;;;;;;;;;;;;;;;1e1;;;;;:ii;;;:ii;;";";;;";";
          ;;;1111111;;;;;;$ii;;;;;;;;;;;;1111e1111;;:ii;;;:ii;;";;;;;";;;
          ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        EOM
        <<~EOM,
          A small note at the side says: Try #{bold "th-search --more"}...
        EOM
      ]

      def execute(arg)
        print_searching

        if arg.chomp == "--more"
          print_searching
          puts <<~EOM
            You found #{font(:link, "TreasureDetector")}!
            You can use it to find treasures.
          EOM
          return
        end

        hint = HINTS[TreasureHunt.instance.hint_count % HINTS.size]
        puts hint
        TreasureHunt.instance.hint_count += 1
      end

      private

      def print_searching
        print "You search the area"
        STDOUT.flush
        3.times do
          sleep 0.2
          print "."
          STDOUT.flush
        end
        puts "\n\n"
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
    f0d7142453d858524468066d46ccbe9db7292e87cb06cfab3ff6422fc6bbb082
  ]

  attr_accessor :hint_count
  attr_reader :treasures

  def initialize
    require "js" if wasm?

    load!
    @hint_count = 0
    puts <<~EOM
      Welcome to TreasureHunt game on IRB.
      You can use many IRB features for exploring treasure.

      There are many useful IRB commands:
        #{bold "help"} Shows IRB commands.
        #{bold "ls"} Shows methods, constatns and variables in current workspace.
        #{bold "cd"} Changes current workspace.
        ...

      You could find some TreasureHunt commands with #{bold "help"} command.
      If you found treasure, please use #{bold "th-capture"} command: th-capture TREASURE-CODE

      #{ font :yellow, "At first, try" }: puts \"Hello, STORES\"
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

  def reset!
    @treasures = []
    save!
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
IRB::Command.register("th-search", TreasureHunt::IrbCommand::Search)

# Initialize TreasureHunt
TreasureHunt.instance

puts_method = method(:puts)
Kernel.define_method(:puts) do |*args|
  if args[0] == "Hello, STORES"
    puts_method.call(font :yellow, "You found a treasure!: ST-HELLO\n")
    puts_method.call("You can use th-capture command to capture this treasure: #{bold "th-capture ST-HELLO"}")
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

    private def register(event_type, hook)
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
        Let's call: #{font(:link, "Tablet.read")}.
      EOM
    end
  end

  self.register(:explore, -> { puts font(:yellow, "You found a treasure!: RI-STONE") })
end

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
  class << self
    def hint
      puts <<~EOM
        #{font(:link, "TreasureDetector")}#{bold ".nop"} is not implemented.
        Based on the method name, it seems nothing needs to be done.

        You can define it in IRB.
      EOM
    end

    def use
      nop
      puts font :yellow, "You got a treasure! DT-FIXME"
    end
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
