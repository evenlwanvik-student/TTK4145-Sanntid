defmodule Utils do
  @states [:idle, :stop, :running, :door_open]
  @buttons [:up, :down, :cab]
  @number_of_floors 3

  def get_all_buttons do
    %{up: 0..@number_of_floors - 1,
      down: 1..@number_of_floors,
      cab: 0..@number_of_floors}
  end

  
end

defmodule State do
 #@possible_directions[:up, :down, :idle]
  defstruct direction: :idle, floor: 0
end

defmodule Order do 
  defstruct direction: :down, floor: 0
end

defmodule NodeScore do
  defstruct node: Node.self(), score: 0
end
