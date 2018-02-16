require "spec_helper"
require 'pry'
require 'dotenv/load'

describe Lita::Services::LunchAssigner, lita: true do
  let(:robot) { Lita::Robot.new(registry) }
  let(:redis) { Lita::Handlers::LunchReminder.new(robot).redis }
  let(:subject) { described_class.new(redis) }

  it "returns a list of current lunchers" do
    expect(subject.current_lunchers_list).to eq([])
  end

  it "adds lunchers" do
    subject.add_to_lunchers("alfred")
    expect(subject.lunchers_list).to eq(["alfred"])
  end

  it "removes lunchers" do
    subject.add_to_lunchers("alfred")
    expect(subject.lunchers_list).to eq(["alfred"])
    subject.remove_from_lunchers("alfred")
    expect(subject.lunchers_list).to eq([])
  end

  it "retrieves karma =0 if not set" do
    expect(subject.get_karma("agustin")).to eq(0)
  end

  it "sets and retrieves karma" do
    subject.set_karma("agustin", 1000)
    expect(subject.get_karma("agustin")).to eq(1000)
  end

  it "create a hash that handles negative karma" do
    subject.add_to_lunchers("alfred")
    subject.set_karma("alfred", 10)
    subject.add_to_lunchers("peter")
    subject.set_karma("peter", -10)
    lkh = subject.karma_hash(subject.lunchers_list)
    expect(lkh["alfred"]).to eq(21)
    expect(lkh["peter"]).to eq(1) # 0 karma is 1
  end

  it "allows for a single no karma man to win" do
    subject.set_karma("alfred", 0)
    subject.add_to_lunchers("alfred")
    subject.add_to_current_lunchers("alfred")
    subject.pick_winners(1)
    expect(subject.winning_lunchers_list).to eq(['alfred'])
  end

  fit "considerates karma for shuffle and decreases to winners" do
    subject.add_to_lunchers("alfred")
    subject.set_karma("alfred", 0)
    subject.add_to_lunchers("peter")
    subject.set_karma("peter", -100)
    subject.add_to_current_lunchers("alfred")
    subject.add_to_current_lunchers("peter")
    subject.pick_winners(1)
    expect(subject.winning_lunchers_list).to eq(['alfred'])
    expect(subject.get_karma("alfred")).to eq(-1)
  end

  it "interates until every spot has been asigned" do
    subject.add_to_current_lunchers("alfred")
    subject.set_karma("alfred", 0.1)
    subject.add_to_current_lunchers("peter")
    subject.set_karma("peter", 100)
    subject.add_to_current_lunchers("john")
    subject.set_karma("john", 1)
    subject.add_to_current_lunchers("john")
    subject.set_karma("john", 2)
    subject.add_to_current_lunchers("john")
    subject.set_karma("john", 6)
    subject.pick_winners(2)
    expect(subject.winning_lunchers_list).to include('peter')
    expect(subject.winning_lunchers_list.count).to eq(2)
  end

  it "retrieves wager =1 if not set" do
    expect(subject.get_wager('agustin')).to eq(1)
  end

  describe 'set_wager' do
    before do
      subject.set_karma("agustin", -100)
      redis.del('agustin:wager')
    end

    context 'with enough karma points' do
      it "sets and retrieves wager" do
        subject.set_wager("agustin", 50)
        expect(subject.get_wager("agustin")).to eq(50)
      end
    end

    context 'with not enough karma points' do
      it "sets and retrieves wager" do
        subject.set_wager("agustin", 51)
        expect(subject.get_wager("agustin")).to eq(1)
      end
    end
  end

  describe 'karma_hash_with_wager' do
    before do
      subject.add_to_lunchers('ignacio')
      subject.add_to_lunchers('jaime')
      subject.add_to_lunchers('agustin')
      subject.set_karma('ignacio', -5)
      subject.set_karma('jaime', -20)
      subject.set_karma('agustin', -15)
      subject.set_wager('jaime', 10)
      subject.set_wager('agustin', 5)
    end

    it "get's hash correctly" do
      expect(subject.karma_hash_with_wager(['ignacio', 'jaime', 'agustin'])).to(
        include('ignacio' => 7, 'agustin' => 1, 'jaime' => 1)
      )
    end
  end

  describe 'reset_lunchers' do
    before do
      subject.add_to_lunchers('ignacio')
      subject.add_to_lunchers('agustin')
      subject.add_to_lunchers('jaime')
      subject.add_to_current_lunchers('ignacio')
      subject.add_to_current_lunchers('agustin')
      subject.add_to_current_lunchers('jaime')
      subject.add_to_winning_lunchers('ignacio')
      redis.set('already_assigned', true)
      subject.set_karma('jaime', -20)
      subject.set_wager('jaime', 10)
    end

    it 'erases the required variables' do
      subject.reset_lunchers

      expect(subject.winning_lunchers_list).to eq([])
      expect(subject.current_lunchers_list).to eq([])
      expect(subject.already_assigned?).to be false
      expect(subject.get_wager('jaime')).to eq(1)
    end
  end

  describe 'winners lose wagered points' do
    before do
      subject.add_to_current_lunchers('jaime')
      subject.set_karma('jaime', -10)
      subject.set_wager('jaime', 5)
      subject.pick_winners(1)
    end

    it { expect(subject.get_karma('jaime')).to eq(-15) }
  end
end
