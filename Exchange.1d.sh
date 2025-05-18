#!/bin/bash
# <xbar.title>Gold, Silver, Pepper Price, BTC, living expenses</xbar.title>
# <xbar.version>v1.4</xbar.version>
# <xbar.author>ശ്രീരാം മേനോൻ</xbar.author>
# <xbar.desc>Gives the real price of items in silver or gold. Silver, Gold, Pepper, Monthly expenses in Mumbai, and Bitcoin prices are used.</xbar.desc>
# <xbar.dependencies>bash, curl, jq</xbar.dependencies>

# Enable or disable time debugging
time_debug=0  # Set to 1 to enable, 0 to disable
# Variables to store timings (optional initialization)
start_time=0
total_time=0
end_time=0
gold_time=0
mandi_time=0
usd_to_inr_time=0
malayalam_date_time=0
# Function to measure time conditionally
measure_time() {
  if [ "$time_debug" -eq 1 ]; then
    date +%s%3N | sed 's/N$//'
  else
    echo 0
  fi
}

if [ "$time_debug" -eq 1 ]; then
  start_time=$(measure_time)
fi

export PATH="/opt/homebrew/bin:$PATH"

# API Keys
MANDI_API_KEY="get_your_own"
#Mandi API sourced from https://www.data.gov.in/resource/current-daily-price-various-commodities-various-markets-mandi
EXCHANGE_API_KEY="get_your_own"
#Exchange API sourced from https://www.exchangerate-api.com/docs/overview
LIVING_COST_API_KEY="get_your_own"
#Living Cost API sourced from rapidapi.com. One alternate is https://github.com/zackharley/cost-of-living-api/tree/master

# URLs for APIs
MANDI_URL="https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070"
EXCHANGE_URL="https://v6.exchangerate-api.com/v6/$EXCHANGE_API_KEY/latest/USD"
GOLD_URL="https://api.gold-api.com/price"
LIVING_COST_URL="https://cost-of-living-and-prices.p.rapidapi.com/prices?city_id=887" #City ID for Mumbai


start_LC=$(measure_time) #time_testing


# Fetch cost of living API response
LC_response=$(curl --silent --request GET \
  --url "$LIVING_COST_URL" \
  --header "x-rapidapi-key: $LIVING_COST_API_KEY")
#--header "x-rapidapi-host: cost-of-living-and-prices.p.rapidapi.com" \ #This line removed as second line

# Validate the response
if [[ -z "$LC_response" || "$LC_response" == "null" ]]; then
  echo "Error: Unable to fetch cost of living data."
  exit 1
fi

# Extract data using jq, removing quotes with `-r`
rent=$(echo "$LC_response" | jq -r '.prices[] | select(.good_id==28) | .usd.avg')
childcare=$(echo "$LC_response" | jq -r '.prices[] | select(.good_id==4) | .usd.avg')
utilities=$(echo "$LC_response" | jq -r '.prices[] | select(.good_id==54) | .usd.avg')
internet=$(echo "$LC_response" | jq -r '.prices[] | select(.good_id==55) | .usd.avg')
dining_out=$(echo "$LC_response" | jq -r '.prices[] | select(.good_id==37) | .usd.avg')
taxi_trip=$(echo "$LC_response" | jq -r '.prices[] | select(.good_id==49) | .usd.avg')

# Groceries
bread=$(echo "$LC_response" | jq -r '.prices[] | select(.good_id==18) | .usd.avg')
milk=$(echo "$LC_response" | jq -r '.prices[] | select(.good_id==20) | .usd.avg')
eggs=$(echo "$LC_response" | jq -r '.prices[] | select(.good_id==15) | .usd.avg')
chicken=$(echo "$LC_response" | jq -r '.prices[] | select(.good_id==13) | .usd.avg')
rice=$(echo "$LC_response" | jq -r '.prices[] | select(.good_id==25) | .usd.avg')
vegetables=$(echo "$LC_response" | jq -r '.prices[] | select(.good_id==26) | .usd.avg')
fruits=$(echo "$LC_response" | jq -r '.prices[] | select(.good_id==9) | .usd.avg')


# Additional calculations
weekly_taxi_trips=8 # 4 round trips per week (2 trips per day)
monthly_taxi_cost=$(echo "$taxi_trip * 10 * $weekly_taxi_trips * 4" | bc)  # Avg 10 km per trip
monthly_dining_cost=$(echo "$dining_out * 4" | bc)  # Dining out 4 times a month

# Monthly grocery estimate for a family of 3
monthly_groceries=$(echo "($bread * 8) + ($milk * 30) + ($eggs * 4) + ($chicken * 4) + ($rice * 5) + ($vegetables * 6) + ($fruits * 6)" | bc)

# Total monthly cost of living
Living_Cost_USD=$(echo "$rent + $childcare + $utilities + $internet + $monthly_taxi_cost + $monthly_dining_cost + $monthly_groceries" | bc)



end_LC=$(measure_time)
LC_time=$((end_LC - start_LC))



# Fixed conversion factor
TROY_OUNCE_TO_GRAM=31.1035

# Fetch Gold Price in USD per troy ounce
start_gold=$(measure_time) #time_testing

api_response=$(curl -s "$GOLD_URL/XAU") #Single call to store all details for API calling efficiency
gold_price_usd=$(echo "$api_response" | jq -r '.price') #extracting gold price
updated_greg_date=$(echo "$api_response" | jq -r '.updatedAt' | cut -d'T' -f1) #extracting updated date without time
clean_date=$(gdate -d "$updated_greg_date" +"%Y-%m-%d" 2>/dev/null) #had to use gdate and not date
if [[ -z "$clean_date" ]]; then
  echo "Error: Clean date not generated from updated_greg_date." >&2
fi

# Fetch Silver Price in USD per troy ounce
silver_price_usd=$(curl -s "$GOLD_URL/XAG" | jq -r '.price')

# Fetch Bitcoin Price in USD
btc_price_usd=$(curl -s "$GOLD_URL/BTC" | jq -r '.price')

end_gold=$(measure_time)
gold_time=$((end_gold - start_gold))

# Fetch USD to INR Exchange Rate
start_usd_to_inr=$(measure_time)
usd_to_inr=$(curl -s "$EXCHANGE_URL" | jq -r '.conversion_rates.INR')
end_usd_to_inr=$(measure_time)
usd_to_inr_time=$((end_usd_to_inr - start_usd_to_inr))

# Fetch Mandi Prices for Pepper in Perumbavoor (Ernakulam)
start_mandi=$(measure_time)

mandi_response=$(curl -s "$MANDI_URL?api-key=$MANDI_API_KEY&format=json&limit=50000" \
| jq -r '.records[] 
         | select(.state == "Kerala") 
         | select(.district == "Ernakulam") 
         | select(.commodity == "Black pepper") 
         | select(.market == "Perumbavoor") 
         | .modal_price')

end_mandi=$(measure_time)
mandi_time=$((end_mandi - start_mandi))

# Validate API Responses
error_messages=""  # Collect error messages here

if [[ -z "$gold_price_usd" || -z "$silver_price_usd" || -z "$btc_price_usd" ]]; then
  error_messages+="Gold/Silver/BTC Price API failed.\n"
fi

if [[ -z "$usd_to_inr" ]]; then
  error_messages+="USD to INR Exchange API failed.\n"
fi

if [[ -z "$mandi_response" ]]; then
  error_messages+="Mandi Prices API failed.\n"
fi

if [[ -z "$LC_response" ]] || (( $(echo "$Living_Cost_USD <= 0" | bc -l) )); then
  error_messages+="Cost of living API failed.\n"
fi

# Calculating Prices in INR per gram of metal (only if no critical errors)
if [[ -z "$gold_price_usd" || -z "$silver_price_usd" || -z "$btc_price_usd" || -z "$usd_to_inr" ]]; then
  silver_price_inr="N/A"
  silver_price_inr_rounded="N/A"
  gold_price_inr_rounded="N/A"
  btc_price_in_silver_rounded="N/A"
  price_in_silver="N/A"
else
  silver_price_inr=$(echo "scale=2; ($silver_price_usd / $TROY_OUNCE_TO_GRAM) * $usd_to_inr" | bc)
  silver_price_inr_rounded=$(printf "%.0f" "$silver_price_inr")

  gold_price_inr=$(echo "scale=2; ($gold_price_usd / $TROY_OUNCE_TO_GRAM) * $usd_to_inr" | bc)
  gold_price_inr_rounded=$(printf "%.0f" "$gold_price_inr")
  gold_price_in_silver=$(echo "scale=2; $gold_price_inr / $silver_price_inr" | bc)
  gold_price_in_silver_rounded=$(printf "%.0f" "$gold_price_in_silver")

  btc_price_inr=$(echo "scale=2; $btc_price_usd * $usd_to_inr" | bc)
  btc_price_in_silver=$(echo "scale=2; $btc_price_inr / $silver_price_inr" | bc)
  btc_price_in_silver_rounded=$(printf "%.0f" "$btc_price_in_silver")
  btc_price_in_gold=$(echo "scale=2; $btc_price_inr / $gold_price_inr" | bc)
  btc_price_in_gold_rounded=$(printf "%.0f" "$btc_price_in_gold")

  # Process Pepper Price
  pepper_price_per_quintal=$mandi_response
  pepper_price_per_kg=$(echo "scale=2; $pepper_price_per_quintal / 100" | bc)  # Convert ₹ per quintal to ₹ per kg
  pepper_price_in_silver=$(echo "scale=2; $pepper_price_per_kg / $silver_price_inr" | bc)
  gold_price_in_pepper=$(echo "scale=2; $gold_price_inr / $pepper_price_per_kg" | bc)

  #Living Cost Price with one decimal place
  Living_Cost_INR=$(echo "scale=2; $Living_Cost_USD * $usd_to_inr" | bc)
  Living_Cost_gold=$(echo "scale=2; $Living_Cost_INR / $gold_price_inr" | bc)
  Living_Cost_gold_rounded=$(printf "%.1f" "$Living_Cost_gold")
fi

# Call the Python script to get the solar date
start_malayalam_date=$(measure_time)
malayalam_date=$(python3 /Users/user/Files/SwiftBar/solar_calendar.py "$updated_greg_date")
#just_check_date=$(python3 /Users/user/Files/SwiftBar/solar_calendar.py)
end_malayalam_date=$(measure_time)
malayalam_date_time=$((end_malayalam_date - start_malayalam_date))


if [ "$time_debug" -eq 1 ]; then
  end_time=$(measure_time)
  total_time=$((end_time - start_time))
fi


# Display the menubar content
if [[ -n "$gold_price_inr_rounded" ]]; then
  echo "🟡: $gold_price_inr_rounded₹"
fi

if [[ -n "$gold_price_in_silver_rounded" ]]; then
  echo "🟡: $gold_price_in_silver_rounded🪙" #രജതം
fi

if [[ -n "$pepper_price_in_gold" ]]; then
  echo "🟡: $gold_price_in_pepper കുരുമുളക്"
fi

if [[ -n "$btc_price_in_gold_rounded" ]]; then
  echo "₿: $btc_price_in_gold_rounded🟡" #സ്വൎണം
fi

if [[ -n "$Living_Cost_gold_rounded" && $(echo "$Living_Cost_gold_rounded > 0" | bc -l) -eq 1 ]]; then
  echo "വ്യയഃ: $Living_Cost_gold_rounded🟡" #സ്വൎണം
fi

echo "---"  # Everything below this appears in the dropdown

#ഉണ്ടാക്കേണ്ട പണം കണക്കാക്കാൻ.
#2.5% ആണ് വാർഷിക പലിശ SGBക്ക് വരുന്നത്. അതിന്റെ 12ൽ 1 ആവണം ജീവിതചിലവ്.
if [[ -n "$Living_Cost_gold_rounded" ]]; then
  Wealth_required=$(printf "%.0f" $(echo "$Living_Cost_gold_rounded * 12 * 40" | bc)) #removing decimal
  echo "ധനസമാഹരണലക്ഷ്യം: $Wealth_required സ്വൎണം"
else
  error_messages+="Unable to calculate Wealth Required.\n"
fi


# Show Kerala date if it works. Otherwise English date.
if [[ -n "$malayalam_date" ]]; then
  echo "സൂചികാദിനം: $malayalam_date"
else
  echo "Updated Date: $updated_greg_date"
fi

echo "സ്വർണം വെള്ളി എന്നിവ മാഷ. കുരുമുളക് കിലൊ.ജീവിതചിലവ് മാസത്തിൽ"
echo "8രത്തി=മാഷ. 1000മാഷ=കിലൊ."

# Display error messages (if any)
if [[ -n "$error_messages" ]]; then
  echo "---"
  echo -e "$error_messages"
fi

if [ "$time_debug" -eq 1 ]; then
  echo "Time taken for Living Cost API: ${LC_time}ms"
  echo "Time taken for Gold API: ${gold_time}ms"
  echo "Time taken for Mandi API: ${mandi_time}ms"
  echo "Time taken for Currency API: ${usd_to_inr_time}ms"
  echo "Time taken for Malayalam Date Calculation: ${malayalam_date_time}ms"
  echo "Total time taken: ${total_time}ms"
fi
