require "./spec_helper"

Spectator.describe Torinfo do
  it "has a version" do
    expect(Torinfo::VERSION).not_to be_empty
  end
end
