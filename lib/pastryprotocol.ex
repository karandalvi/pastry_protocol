defmodule PastryProtocol do

  def main(input) do
    [numNodes, numRequests] = input
    numNodes = String.to_integer(numNodes)
    numRequests = String.to_integer(numRequests)
    IO.puts "Nodes   : #{numNodes}"
    IO.puts "Requests: #{numRequests}"
    nodeList = start(numNodes, [], [])
    send self, {:getStats}
    loop(nodeList, numNodes, numRequests, [])
  end

  def start(numNodes, nodeList, pidList) when numNodes > 0 do
    newNode = :crypto.hash(:md5, Integer.to_string(numNodes)) |> Base.encode16()
    newPid = spawn(PNode, :init, [newNode])
    send newPid, {:console, self}
    if length(pidList) > 0 do
      # send newPid, {:join, Enum.at(pidList, round(:math.floor(:rand.uniform() * length(pidList))))}
      send newPid, {:join, Enum.at(pidList, 0)}
    end
    nodeList = nodeList ++ [newNode]
    pidList = pidList ++ [newPid]
    start(numNodes-1, nodeList, pidList)
  end

  def start(numNodes, nodeList, pidList) when numNodes <= 0 do
    [nodeList, pidList]
  end

  def loop(nodeList, numNodes, numRequests, hops) do
    receive do
      {:getStats} ->
        nameList = Enum.at(nodeList, 0)
        pidList = Enum.at(nodeList, 1)
        :timer.sleep(8000)
        for x <- Enum.at(nodeList, 1) do
          send x, {:print}
          r = round(:math.floor(:rand.uniform() * length(pidList)))
          # send x, {:sendRequest, Enum.at(pidList, r), Enum.at(nameList, r)}
        end
        loop(nodeList, numNodes, numRequests, hops)

      {:collectHopNumber, hopCount} ->
        hops = hops ++ [hopCount]
        IO.inspect length(hops)
        # if length(hops) == (numRequests * numNodes) do
        #   IO.puts "All hops completed"
        # end
        loop(nodeList, numNodes, numRequests, hops)
    end
  end
end
