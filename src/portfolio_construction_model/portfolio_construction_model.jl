
"""
Struct needed to generate
target portfolio weights

Fields
------
- `broker`
- `portfolio_id::String`
- `universe`
- `order_sizer`
- `portfolio_optimizer`
- `alpha_model`
"""
struct PortfolioConstructionModel
    broker
    portfolio_id::String
    universe
    order_sizer
    portfolio_optimizer
    alpha_model
    #TODO: add risk/cost models
    # risk_model
    # cost_model::CostModel
end

function _get_assets(pcm)
    uni_assets = _get_assets(pcm.universe)
    port_assets = _get_assets(pcm.broker.portfolios[pcm.portfolio_id])
    return unique([uni_assets..., port_assets...])
end

function _get_current_positions(pcm)
    return pcm.broker.portfolios[pcm.portfolio_id].pos_handler.positions
end

function _create_rebalance_orders(
    current_positions::Dict{Symbol,Position},
    target_positions::Dict{Asset,Int},
    dt::DateTime,
)
    target_positions_assets = keys(target_positions)
    rebalance_orders_dict = Dict{Asset,Order}()
    for (_, position) in current_positions
        if !(position.asset in target_positions_assets)
            rebalance_orders_dict[position.asset] = Order(
                dt, -position.net_quantity, position.asset
            )
        end
    end

    # buy/sell orders for current/new positions
    for (asset, target_quantity) in target_positions
        if asset.symbol in keys(current_positions)
            current_quantity = current_positions[asset.symbol].net_quantity
            if current_quantity == target_quantity
                continue
            else
                rebalance_orders_dict[asset] = Order(
                    dt, target_quantity - current_quantity, asset
                )
            end
        else # new position
            rebalance_orders_dict[asset] = Order(dt, target_quantity, asset)
        end
    end
    buy_orders = [i[2] for i in rebalance_orders_dict if i[2].direction > 0]
    sell_orders = [i[2] for i in rebalance_orders_dict if i[2].direction < 0]
    return [sell_orders..., buy_orders...]
end

"""
```julia
_create_rebalance_orders(pcm, dt::DateTime)
```

Create rebalance orders to create the target portfolio

Parameters
----------
- `pcm`
- `dt::DateTime`

Returns
-------
- `Dict{Asset, Int}`: Rebalance orders
"""
function _create_rebalance_orders(pcm, dt::DateTime)
    weights = pcm.alpha_model(dt)
    target_positions = pcm.order_sizer(pcm.broker, pcm.portfolio_id, weights, dt)
    current_positions = _get_current_positions(pcm)
    rebalance_orders = _create_rebalance_orders(current_positions, target_positions, dt)
    return rebalance_orders
end
