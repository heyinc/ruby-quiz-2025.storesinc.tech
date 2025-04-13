require "irb"
require "irb/context"

require "base64"
require "digest"
require "singleton"

FONT_STYLE = {
  bold: "1",
  yellow: "33",
  red: "31",
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
          While you wander, you remember:
          "The RubyKaigi 2025 opening #{font :link, "Keynote" } was fun!"
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

  # Digest::SHA256.hexdigest(treasure)
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
    f7f9e259a5f212e12a69de3f38094aaf0179663f77e024acedbea7c2f224ce00
    939ef55a8e99c91231e1de13a7438506f7a4a1c060c9e75252bf0ba825d7db94
    a16071242afb8a9debadd51432e44ec310cceaadf4aac50d1bc7b73c89f82295
    dc75587f056351b4e9f65f7a645b2226729df118ae2408cf54bb19d862609969
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

      #{load_game_image}

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

      if treasures.size == TreasureHunt::TREASURE_DIGESTS.size
        puts font(:yellow, <<~EOM.chomp)
        Congratulations!
        You have found all the treasures hidden in the world and are closer to the wisdom of the ancients.

        For more knowledge, please wait for the next TreasureHunt game update.
        EOM
      end
    end
  end

  def load_game_image
    wasm? ? JS.global[:gameImage].to_s : File.read(File.join(File.dirname(__dir__), "images", "game.sixel"))
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
  class ReverseSide
    class << self
      def read
        puts <<~EOM
          The reverse side of the tablet says:
          There is in the #{font :link, "Tablet"}::#{font :link, "ReverseSide"}.sentence.
          Use the tool #{font :red, '/\w\W(?<treasure>\w{2}-(?<e>\p{Emoji})\W\k<e>)/'} to find it.
        EOM
      end

      def sentence
        <<~EOM
          📀TOI🍵🧪KSLM🛢🍉R🧸🎮M🦉M🧫S-🎒💿️🔩ZO🔗I🎨🍣🔋FA📂🔩FJL🥷PRA🧭G🧪🍩W📚N🪄C🔋️ORX️ 🧪🔦NQSJA🔑🐉🧊EL🧪TY️ WQ️ 🧃🗺📫--🐧SV🪅🐧RF🚨OI🔨PB💿🔧‍Y📡️🛹ZN🧩DT️🧊L👾ZOJ🦾🍰D🍵XY-️ 📷WCA🗿️
          KY💎X🌋DJO🛎FG-🗿🧃🔦PERQ🍓⚡📓🌇MBK🌅🌸🪅IHIXPYT🕹🧃F🌰🏝I⚡🔦KQ🐠️WA📷🌈🎨💿🦖🦊🔗📌G🚨AJ🔩M🎟️ D🔦R🦊U🛸🪅️W🥟QK♂🐾🗓J🪄R🗓🧤📓JIK🧱XM🧊🍰🧵E🛠🧊YRAG🍜JNKTIDJ🍉🛰R️ HV🧃TX📷N🍩BO🎨🎼🐲
          G🪓UXR🌈🧼-🧭P-H🪄🍩🛹🧙🧊-A🧤📦🔋🌅🪁️🧬XXX🎳🗺E🔨🔦L🧙N🎯🧃🦖️🪓🧱🥽💿👾🧱🗿R🍉WQB🧯🐾️🧸🍙E🛠N🦋O🧊EAV💿🍀🍜🎨🔨RRN🦊-K🍀TSM🗺️ 🎲⚡EO🌙C🍉🪓N🗺YZUYQ🧱🛎🧀️I🎼SLE-NG-I📓🛢🔬-JHMP-🪅️-QYK
          🕹TFX️ 💡🦊️🔨🚨🍓🧩🍩C🗿A📦S🔩🌠🍰🕹HN-RE📫K🧪🍰🌈V📉-🍙W📻Q📀YM🐲KX💎X🎂🦴📫🐉🧠HM🍩O🔥️🔧🎨PRL🍓🗜IL🐧WNT🚨HNYYZ️ 🛠L🛢📡🧃🎂WLYCOI🪓H️ 📈F🚨GY🌸️XL🛸🕹🪁U🌅🍓M🕹🧊X🍰🧫RG🗿🥟🧪📀✨🎯🔩Y🦅CE🗓
          🌠IZOAIV📮C-EC🧸WB👾H-🎒🪅🧱🧸F🦴A🔗WE️ F️ 🎼️🛰-📉🦴GJ🔍📜🗺HA🌰👣O🧵O🐠♂️🐠 -📦C✨TP🗺🌇PYCL💡🌈YD🧭G🌠V️ G🍇🔗🛢🧤🔥B🥷UJ🧊Z📷RE-🐾💎🐾HK🎨👾🐉📌A🧬📜P️ WT🔧🌈🧃DJV🎁🪁📻N🧤️Z🐢🍓🍀R💿🧃🌌🧩🪐🍓R
          R📌🐉X🧩📡YD-🦾🎁🌋🛰📫AWDE🐧🧫🧃💎AJ🌅S📦📮🦴♂NV️ NQ📡🔨SR🛠U🗜️ DG️ L🦉XX🧼🦖L️ 🧫JB🗺VE🐧C🔗🌰E🔥🗓🎤🌇I💎🧼H🍰DRI🐉G🪁SC🧊ER️ 🧙⚡V🎤P🔍️P🐬🧪🧸📼📌UYM🎯️🔧-🧪KZ-🌸I--🕹📻🎨ET🗜EQ🦾H🧃🎂👾🌋
          -🧠O🔑🧱📻✨NQ🥟JP-🐢️PL💡V⚡🐧B🥷📋🧃🛢A♂️ C🪅ZY-💎XTQ🐾P📮♂🧭🔗📻BNHV🚀J🦉R🌈🧫R🍓-🔗P🦴🧙️J🦾🍛🛰🌌🧊L📌NG🔨G️ 🪄Q🧬BD🎲🔨Z-🧃-📌JM-F👣-🎟🧤🥟UXJQVAIB🦴N🍣O🎁🧠🧱🎧GYUKM🦉X-📋⚡S🎟🔑F🔬
          🧃P🌈HL🎳O🌸DV️ 🔥🎲🔥BVTS🗜Q️ ED📡🔑BO📉D🔍📂🛎️ 🧫R📈🎁E🌸🦊CB🗓🧼F🐲🦴🔨🛠AVDP👾️🔦💡R🐢WAD🍣BQR🍩🧭PILK🦴F🛠🧊🪅💿V🌰LI🦊🎁📻KZR️ C️ 🚀V🔥️🪓🌋♂🦅️B📀T-📋🌈🕹BMD️ ZM🌇👣📓W️ I🧸🧙T-🎯SJ🎲🧵
          🪤X🗓O🍀🗃🍣️🍰VX🌠🦾🧤H🌇🎟️ 📦🧃🔩️📡-HVGU💡CQU🚀📷🌠EMSK📈M📂🌸️🌋🚀N️ 🥟YUV🐾🍇📼W📚🔨🚨🔩📋🌠A🧼I🎒-🥷Q🧼🎧🌈QR🦋Q🌙️S🪁F🍀📻️🔥🧀🛢R️ 🐲X🌋FDS🧀️🍜🗺⚡RC🦴U🧊🗃FIIOZ🧊🌸XN🛹AN🛸🦋CZ️ G🍇📂📼🍣
          🚨X️ RF🦖🎟X🧭RAV🧸XKFS🗿🎮🗿️OA-🎼📀GQ🦋🧭A🌅🔗RSO️ 🦉Z️ 🗓🌸👾N🎮BE🎳📼B🍰🍉P🧃🧊I🧙P🎳N🦾IFVPZ🧀👣-X🕹🔬AM🌈️🕹️ TR-🎤O🎂🧪📚-🗺AOG📉🌰🦾DSYPU🔑IW🎁II🎮🎧🚨️🎼OWP🐢🎂Z🗜️ Q🥽🎼HN-L-B🥟
        EOM
      end
    end
  end

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

class Keynote
  CP290_TABLE = Hash[*(
    "\0\0\0\0\0\0\0\0\0\0\0\0\0\r\0\0" +
    "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0" +
    "\0\0\0\0\0\n\0\e\0\0\0\0\0\0\0\0" +
    "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0" +
    " ｡｢｣､･ｦｧｨｩ£.<(+|" +
    "&ｪｫｬｭｮｯ\0ｰ\0!\\*);¬" +
    "-/abcdefgh\0,%_>?" +
    "[ijklmnop`:#@'=\"" +
    "]ｱｲｳｴｵｶｷｸｹｺqｻｼｽｾ" +
    "ｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉr\0ﾊﾋﾌ" +
    "~‾ﾍﾎﾏﾐﾑﾒﾓﾔﾕsﾖﾗﾘﾙ" +
    "^¢/tuvwxyzﾚﾛﾜﾝﾞﾟ" +
    "{ABCDEFGHI\0\0\0\0\0\0" +
    "}JKLMNOPQR\0\0\0\0\0\0" +
    "$€STUVWXYZ\0\0\0\0\0\0" +
    "0123456789\0\0\0\0\0\0"
  ).each_char.map.with_index{|ch, i| [i, ch == "\0" ? nil : ch] }.flatten]

  LOCATION = wasm? ? "#{ENV["HOME"]}/treasure.txt" : "/tmp/treasure.txt"

  File.write(LOCATION, "'p\xF3\xF3u\xE8w\xB4@gw\xB4ve@b@\xB3\x9Bfb\xAB\xB4\x9BfZz@\xD2\xC5`\xC3\xD7\xF2\xF9\xF0'pu%%\xE6ftdwuf@\xB3w@\xC3\xD7\xF2\xF9\xF0@fvdweqvh@\xB6w\x9BteZ%\xC3\xD7\xF2\xF9\xF0@\x84\xBD\x8AX\x94\xBEH\xBD\x88\xBE\x9A@\x8F\x86\x82\xA2@\xAC\x83\x8A\x90Z%")
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

class << File
  RUBY_LOGO_AA = File.join(File.dirname($LOADED_FEATURES.select { _1.include?("easter-egg.rb") }[0]), "ruby_logo.aa")
  alias_method :original_read, :read

  def read(*args, **kwargs)
    if args[0] == RUBY_LOGO_AA
      <<EOM
TYPE: UNICODE_LARGE

      ▄▄        ▄▄                 ▄▄▄▄    ▄▄▄▄▄▄▄▄    ▄▄▄▄    ▄▄▄▄▄▄    ▄▄▄▄▄▄▄▄    ▄▄▄▄       ▄▄
     ████      ████              ▄█▀▀▀▀█   ▀▀▀██▀▀▀   ██▀▀██   ██▀▀▀▀██  ██▀▀▀▀▀▀  ▄█▀▀▀▀█      ██
     ████      ████              ██▄          ██     ██    ██  ██    ██  ██        ██▄          ██
    ██  ██    ██  ██              ▀████▄      ██     ██    ██  ███████   ███████    ▀████▄      ██
    ██████    ██████    █████         ▀██     ██     ██    ██  ██  ▀██▄  ██             ▀██     ▀▀
   ▄██  ██▄  ▄██  ██▄            █▄▄▄▄▄█▀     ██      ██▄▄██   ██    ██  ██▄▄▄▄▄▄  █▄▄▄▄▄█▀     ▄▄
   ▀▀    ▀▀  ▀▀    ▀▀             ▀▀▀▀▀       ▀▀       ▀▀▀▀    ▀▀    ▀▀▀ ▀▀▀▀▀▀▀▀   ▀▀▀▀▀       ▀▀
EOM
    else
      original_read(*args, **kwargs)
    end
  end
end

module IRB
  class << self
    alias_method :original_easter_egg, :easter_egg
    private def easter_egg(_type=nil)
      original_easter_egg(:logo)
    end
  end
end

IRB.start if __FILE__ == $0
