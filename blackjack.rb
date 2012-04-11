#!/usr/bin/env ruby

=begin
  * Name: Ruby Blackjack
  * Description: Ruby Blackjack is a simple command line game of Blackjack
  * Author: Paul Sorensen
=end




# Base class for Blackjack games
class BlackjackGame
  def initialize
    @players = []
    @rounds_played = 0        
    @bets = {}
    @hands = {}
    setup
  end



  # stub for setting up game
  def setup

  end



  def run
    begin     
      @rounds_played += 1
    end while run_round   
  end



  private

  # function to decide whether game should continue after each round
  def keep_playing?
    for player in @players
      if player.get_available_money == 0
        boot_player(player)
      end
    end

    if @players.empty?
      return false
    end
  end



  # remove player from game
  def boot_player(player)
    @players.delete(player)
  end



  # stub for indicating to interface the beginning of a player's turn
  # example: "Player 1's turn."
  def indicate_turn(player)

  end



  # stub for indicating to interface what action a player takes
  # example: "Player 3 hits".
  def indicate_action(player, action)

  end



  # stub for indicating to interface the value of a player's hand
  # example: "Player 3 has 4♠ 5♠ K♢."
  def indicate_hand_value(player, hand)

  end



  # runs each round of blackjack
  # returns boolean indicating whether game should run another round
  def run_round
    get_bets
    deal

    #check for and handle dealer blackjack
    if @hands[@dealer][0].is_blackjack?
      handle_dealer_blackjack
      return keep_playing?
    end

    # players do actions
    for player in @players
      run_player_turn(player)
    end

    # dealer does actions
    run_dealer_turn

    showdown

    @bets.clear
    collect_hands
    return keep_playing?
  end



  def get_bets
    for player in @players
      @bets[player] = player.get_bet
    end
  end



  def deal
    for player in @players
      @hands[player] = []
      @hands[player].push(BlackjackHand.new)
      @hands[player][0].add_card(@dealer_shoe.deal())
    end

    @hands[@dealer] = []
    @hands[@dealer].push(BlackjackHand.new)
    @hands[@dealer][0].add_card(@dealer_shoe.deal())

    for player in @players
      @hands[player][0].add_card(@dealer_shoe.deal())
    end

    # this one needs to be a hole card
    hole_card = @dealer_shoe.deal()
    hole_card.set_visible(false)
    @hands[@dealer][0].add_card(hole_card)
  end



  def handle_dealer_blackjack
    showdown
    @bets.clear
    collect_hands
  end



  def run_player_turn(player)
    indicate_turn(player)

    finished_hands = []
    while not @hands[player].empty?
      hand = @hands[player].pop
      turn_done = false

      indicate_hand_value(player, hand)

      if hand.is_blackjack?
        turn_done = true
        finished_hands.push(hand)
      end

      while not turn_done
        if hand.is_busted?
          turn_done = true
          finished_hands.push(hand)          
          break
        end

        actions = get_available_actions(player, hand)
        if actions.length > 1 # skip when only action is to stay
          action = player.get_decision(actions)
        else
          action = 'stay';
        end

        # handle player decision
        case action

        when 'hit'
          hand.add_card(@dealer_shoe.deal)
          indicate_action(player, action)
          indicate_hand_value(player, hand)

        when 'stay'
          turn_done = true
          finished_hands.push(hand)
          indicate_action(player, action)

        when 'surrender'
          turn_done = true
          surrender(player, hand, @bets[player])

        when 'double'
          turn_done = true
          player.bet(@bets[player])
          @bets[player] = 2*@bets[player]
          hand.add_card(@dealer_shoe.deal)
          hand.double_down
          finished_hands.push(hand)
          indicate_action(player, action)
          indicate_hand_value(player, hand)

        when 'split'
          turn_done = true
          # divide bet by hands and add another one of those denominations
          orig_bet = @bets[player] / (@hands[player].length + finished_hands.length + 1)
          player.bet(orig_bet)
          @bets[player] += orig_bet
          @hands[player] = @hands[player] + hand.split_hand
          indicate_action(player, action)
        end
      end
    end

    # replace hands
    @hands[player] = @hands[player] + finished_hands
    finished_hands.clear
  end



  # returns array of available actions based on the hand
  def get_available_actions(player, hand)
    actions = []

    if hand.is_busted? or hand.is_blackjack?
      return actions
    end

    if hand.is_initial_hand?
      if player.get_available_money >= @bets[player]
        actions.push('double')
      end
      actions.push('surrender')
    end

    if hand.can_hit?
      actions.push('hit')
    end

    if hand.can_split?
      actions.push('split')
    end

    actions.push('stay')

    return actions.sort
  end



  def run_dealer_turn
    indicate_turn(@dealer)

    @hands[@dealer][0].flip_hole_card
    indicate_hand_value(@dealer, @hands[@dealer][0])
    while @hands[@dealer][0].get_value < 17
      indicate_action(@dealer, 'hit')
      @hands[@dealer][0].add_card(@dealer_shoe.deal)
      indicate_hand_value(@dealer, @hands[@dealer][0])
    end

    if not @hands[@dealer][0].is_busted?
      indicate_action(@dealer, 'stay')
    end
  end



  # compares each player's hand to the dealer's hand
  def showdown
    dealer_score = @hands[@dealer][0].get_score
    for player in @players
      hand_count = @hands[player].length > 1 ? @hands[player].length : 1
      bet = @bets[player]/hand_count# splits bets for split hands
      @hands[player].each do |hand|
        if hand.get_score == dealer_score
          push(player, hand, bet)
        elsif hand.get_score > dealer_score
          win(player, hand, bet)
        else
          lose(player, hand, bet)
        end
      end
    end
  end



  # calculate winnings and return them to player
  def win(player, hand, bet)
    if hand.is_blackjack?
      winnings = bet*3/2
    else
      winnings = bet
    end
    player.win(winnings + bet)
    @dealer.pay(winnings)
    indicate_result(player, hand, 'win', winnings + bet)
  end



  # collect bets from player
  def lose(player, hand, bet)
    @dealer.collect(bet)
    indicate_result(player, hand, 'lose', bet)
  end



  # return bet to player
  def push(player, hand, bet)
    player.win(bet)
    indicate_result(player, hand, 'push', bet)
  end



  # return half the bet to the player and collect the rest
  def surrender(player, hand, bet)
    winning = bet/2
    player.win(winning)
    @dealer.collect(bet-winning)
    indicate_result(player, hand, 'surrender', bet-winning)
  end



  # places hands back into dealer shoe and shuffles
  def collect_hands
    for player in @players
      for hand in @hands[player]
        @dealer_shoe.return_cards(hand.get_cards)
        @dealer_shoe.shuffle
      end
    end
    @hands.clear
  end
end




# provides console interface to blackjack game
class ConsoleBlackjackGame < BlackjackGame

  def setup
    puts "\n"
    puts "Welcome to Blackjack!"
    puts "♠-♡-♣-♢-♠-♡-♣-♢-♠-♡-♣\n"

    # get player amount and set up each player, tables can hold up to 9
    puts "\tPlease enter the number of players (1-9): "
    player_count = STDIN.gets.to_i

    while player_count > 9 or player_count < 1
      puts "\tInvalid input. Please enter an integer between 1-9: "
      player_count = STDIN.gets.to_i
    end

    # add players to the game
    (1..player_count).each do |i|
      @players.push(ConsolePlayer.new(i))
    end

    # get deck amount and build dealer shoe
    puts "\tPlease enter the amount of decks you would like to play with (1-8) [4]: "
    deck_count = STDIN.gets
    if deck_count == "\n"
      deck_count = 4
    else
      deck_count = deck_count.to_i
      while deck_count < 1 or deck_count > 8
        puts "\tInvalid input. Please enter an integer between 1-8: "
        deck_count = STDIN.gets
        deck_count = deck_count == "\n" ? 4 : deck_count.to_i
      end
    end

    @dealer_shoe = DealerShoe.new(deck_count)
    @dealer = Dealer.new

    puts "The table has #{player_count} players, and the game will be played with #{deck_count} decks of cards\n\n\n"
  end



  def run
    super
    puts "Quitting..."
    puts "Dealer collected $#{@dealer.get_collected_money} in #{@rounds_played} rounds."
  end



  private



  def keep_playing?
    super
    puts "\nRound finished. Enter 'exit' to quit playing or anything else to continue"
    return STDIN.gets != "exit\n"
  end



  def boot_player(player)
    super
    puts "#{player} has run out of money! #{player} is must leave."
  end



  def indicate_hand_value(player, hand)
    if hand.is_blackjack?
      puts "\t#{player} has Blackjack! #{hand}!"
    elsif hand.is_busted?
      puts "\t#{player}'s hand of #{hand} busts! (value: #{hand.get_value})"
    else
      puts "\t#{player} has #{hand} (value: #{hand.get_value})"
    end
    puts "\n"
  end



  def indicate_action(player, action)
    puts "\t#{player} #{action}s."
  end



  def indicate_turn(player)
    puts "#{player}'s turn:\n\n"
  end



  def indicate_result(player, hand, result, amt)
    case result
    when 'win'
      puts "\t#{player} wins $#{amt} on #{hand}.\n\n"
    when 'lose'
      puts "\t#{player} loses $#{amt} on #{hand}.\n\n"
    when 'push'
      puts "\t#{player} pushes on #{hand}.\n\n"
    when 'surrender'
      puts "\t#{player} surrenders hand #{hand} and forfeits $#{amt}.\n\n"
    end
  end



  def deal
    puts "Dealing cards... \n\n"

    super

    for player in @players
      puts "\t#{player} has been dealt #{@hands[player][0]}"
    end

    puts "\tDealer has been dealt #{@hands[@dealer][0]}\n\n"
  end



  def handle_dealer_blackjack
    puts "\tDealer has Blackjack!\n\n"
    super
  end
end




# class to hold functionalities of the blackjack dealer
class Dealer
  def initialize
    @money_collected = 0
  end



  def collect(amt)
    @money_collected += amt
  end



  def pay(amt)
    @money_collected -= amt
  end



  def get_collected_money
    return @money_collected
  end



  def to_s
    "Dealer"
  end
end




# base class for Player
class Player
  
  def initialize(num)
    @money = 1000
    @player_number = num
  end



  def get_available_money
    return @money
  end



  def bet(amt)
    @money -= amt
  end



  def win(amt)
    @money += amt
  end



  # stub for interface to get a player's starting bet
  def get_bet

  end



  # stub for interface to get player's choice of available actions
  def get_decision(actions)

  end



  def to_s
    "Player #{@player_number}"
  end
end




# provides console interface to handle player's input
class ConsolePlayer < Player
  def get_bet
    puts "#{self}, you have $#{get_available_money}. What is your bet?"
    bet = STDIN.gets.to_i
    while bet < 1 or bet > get_available_money
      if bet < 1
        puts "You must bet at least $1"
      else
        puts "You only have $#{get_available_money} to bet"
      end
      bet = STDIN.gets.to_i
    end

    puts "#{self} bets $#{bet}\n\n"

    bet(bet)

    return bet
  end



  def get_decision(actions)
    if(actions.length > 0)
      puts "Enter one of the following actions: (#{actions.join(', ')})"
      action = STDIN.gets.strip!
      while not actions.include?(action)
        puts "Invalid input. Please enter an action (#{actions.join(', ')})"
        action = STDIN.gets.strip!
      end
      puts "\n"
      return action
    end

    return nil
  end
end




# class holds cards and their corresponding value in blackjack
class BlackjackHand
  # class variable holds cards that are valued at 10
  @@ten_cards = ["10", "J", "Q", "K"]



  def initialize(split_hand = false)
    @cards = []
    @split_hand = split_hand
    @doubled_down = false
  end



  def add_card(card)
    @cards.push(card)
  end



  def get_cards
    return @cards
  end



  def flip_hole_card
    if @cards.at(1) != nil
      @cards[1].set_visible(true) # set hole card to be visible
    end
  end



  def is_initial_hand?
    # first 2 cards in beginning of hand
    if @split_hand or @cards.length != 2
      return false
    end
    return true
  end



  def is_blackjack?
    # blackjack only occurs with 2 cards on first hand, not on split hands
    if @split_hand or @cards.length != 2
      return false
    end
    
    if (@cards[0].get_value == "A" and @@ten_cards.include?(@cards[1].get_value)) or (@cards[1].get_value == "A" and @@ten_cards.include?(@cards[0].get_value))
      return true
    end

    return false
  end



  def is_busted?
    return self.get_value > 21
  end



  def can_hit?
    if @doubled_down
      return false
    end
    return self.get_value < 21
  end



  def can_split?
    # can only split in beginning of hand
    if @cards.length != 2
      return false
    end

    if (@cards[0].get_value == @cards[1].get_value) or (@@ten_cards.include?(@cards[0].get_value) and @@ten_cards.include?(@cards[1].get_value))
      return true
    end

    return false
  end



  def get_value
    value = 0
    ace_count = 0
    for card in @cards
      if card.get_value == 'A'
        ace_count +=1
      elsif @@ten_cards.include?(card.get_value)
        value += 10
      else
        value += card.get_value.to_i
      end
    end

    # iterate through different value of aces to achieve the maximum value
    # less than or equal to 21, starting each ace at 11
    ones = 0
    elevens = ace_count
   
    while value + 1*ones + 11*elevens > 21 and ones != ace_count
      ones += 1
      elevens -= 1
    end
       
    return value + 1*ones + 11*elevens
  end



  # used for showdown, returns 22 for blackjack, 0 for busted hand, or the value
  def get_score
    if is_blackjack?
      return 22
    elsif is_busted?
      return 0
    else
      return get_value
    end
  end



  # returns array containing split hand, or self if cannot split
  def split_hand
    if not self.can_split?
      return self
    end

    split_hands = []
    split_hands.push(BlackjackHand.new(true))
    split_hands[0].add_card(@cards[0])
    split_hands.push(BlackjackHand.new(true))
    split_hands[1].add_card(@cards[1])

    return split_hands
  end



  def double_down
    @doubled_down = true
  end



  def to_s
    if self.is_blackjack?
      self.flip_hole_card
    end
    @cards.join(" ")
  end
end




# holds and shuffles cards
class DealerShoe

  def initialize(deck_count)
    @cards = []
    while deck_count > 0
      @cards = @cards + Deck.get_cards
      deck_count -= 1
    end

    shuffle
  end



  def shuffle
    @cards.shuffle!
  end



  def deal
    return @cards.pop()
  end



  def return_cards(cards)
    #check is array full of card objects
    if not cards.kind_of?(Array)
      return
    end
    for card in cards
      if card.kind_of?(Card)
        @cards.push(card)
      end
    end
  end  
end



# represents a card, storing suit, value and whether its visible
class Card
  def initialize(suit, value)
    @suit = suit
    @value = value
    @visible = true
  end



  def set_visible(visible)
    @visible = visible
  end



  def get_value
    return @value
  end



  def to_s
    if @visible
      "#{@value}#{@suit}"
    else
      "[Hidden Card]"
    end
  end
end




# class provides easy creation of a deck of cards
class Deck
  def Deck.get_cards
    cards = []

    suits = ['♠', '♡', '♣', '♢']
    values = ['2','3','4','5','6','7','8','9','10','J','Q','K','A']

    for suit in suits
      for value in values
        cards.push(Card.new(suit,value))
      end
    end

    return cards
  end
end




# Make Ctrl+C exit more cleanly
trap("SIGINT") { exit! }

game = ConsoleBlackjackGame.new
game.run