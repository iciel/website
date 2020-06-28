require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test "#for! with model" do
    user = random_of_many(:user)
    assert_equal user, User.for!(user)
  end

  test "#for! with id" do
    user = random_of_many(:user)
    assert_equal user, User.for!(user.id)
  end

  test "#for! with handle" do
    user = random_of_many(:user)
    assert_equal user, User.for!(user.handle)
  end

  test "reputation sums correctly" do
    user = create :user
    create :user_reputation_acquisition
    create :user_reputation_acquisition, user: user, category: "track_ruby", amount: 1
    create :user_reputation_acquisition, user: user, category: "track_ruby", amount: 2
    create :user_reputation_acquisition, user: user, category: "track_javascript", amount: 4
    create :user_reputation_acquisition, user: user, category: "docs", amount: 8

    assert_equal 15, user.reputation
    assert_equal 3, user.reputation(track_slug: :ruby)
    assert_equal 8, user.reputation(category: :docs)
  end

  test "reputation raises with both track_slug and category specified" do
    user = create :user

    # Sanity check the individuals work
    # before testing them both together
    assert user.reputation(track_slug: :ruby)
    assert user.reputation(category: :docs)
    assert_raises do
      user.reputation(track_slug: :ruby, category: :docs)
    end
  end

  test "has_badge?" do
    user = create :user
    refute user.has_badge?(:rookie)

    create :rookie_badge, user: user
    assert user.reload.has_badge?(:rookie)
  end
end
