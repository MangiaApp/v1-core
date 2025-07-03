const { PinataSDK } = require("pinata");
require("dotenv").config();

class IPFSHelper {
  constructor() {
    this.pinataJwt = process.env.PINATA_JWT;
    this.gatewayUrl = process.env.GATEWAY_URL;
    
    if (this.pinataJwt && this.gatewayUrl) {
      this.pinata = new PinataSDK({
        pinataJwt: this.pinataJwt,
        pinataGateway: this.gatewayUrl
      });
      this.isConfigured = true;
    } else {
      this.isConfigured = false;
    }
  }

  showConfigurationInstructions() {
    console.log("\n🔧 PINATA CONFIGURATION NEEDED:");
    console.log("1. Go to https://app.pinata.cloud/developers/api-keys");
    console.log("2. Create a new API key with admin privileges");
    console.log("3. Copy your JWT token and Gateway URL");
    console.log("4. Create a .env file in the contracts directory with:");
    console.log("   PINATA_JWT=your_jwt_token");
    console.log("   GATEWAY_URL=your_domain.mypinata.cloud");
    console.log("5. Re-run the script\n");
  }

  async uploadJSON(jsonData, fileName) {
   

    try {
      console.log(`📤 Uploading ${fileName} to IPFS...`);
      
      // Convert JSON to File object
      const jsonString = JSON.stringify(jsonData, null, 2);
      const blob = new Blob([jsonString], { type: "application/json" });
      const file = new File([blob], fileName, { type: "application/json" });
      
      // Upload to Pinata
      const upload = await this.pinata.upload.public.file(file);
      
      const ipfsUri = `ipfs://${upload.cid}`;
      console.log(`✅ Successfully uploaded to IPFS: ${ipfsUri}`);
      console.log(`🔗 Gateway URL: https://${this.gatewayUrl}/ipfs/${upload.cid}`);
      
      return ipfsUri;
    } catch (error) {
      console.error(`❌ Error uploading to IPFS:`, error);
      
      // Return a placeholder URI as fallback
      const placeholderHash = "bafkreierror" + Math.random().toString(36).substring(2, 15);
      console.log(`⚠️  Using placeholder URI: ipfs://${placeholderHash}`);
      console.log("📄 JSON that would be uploaded:");
      console.log(JSON.stringify(jsonData, null, 2));
      return `ipfs://${placeholderHash}`;
    }
  }

  // Generate random project metadata following the schema
  generateProjectMetadata() {
    const restaurants = [
      {
        name: "TacoLoco Barcelona",
        description: "Authentic Mexican street food with a modern twist, bringing the flavors of Mexico to the heart of Barcelona.",
        city: "Barcelona",
        country: "Spain",
        locationAddress: "Carrer de Blai, 23, Poble Sec, 08004 Barcelona",
        category: "Mexican Restaurant",
        backgroundColor: "#FF6B35",
        textColor: "#FFFFFF"
      },
      {
        name: "Ramen Zen Tokyo",
        description: "Traditional Japanese ramen bowls crafted with authentic ingredients and time-honored techniques.",
        city: "Tokyo",
        country: "Japan", 
        locationAddress: "3-14-5 Shibuya, Shibuya City, Tokyo 150-0002",
        category: "Japanese Restaurant",
        backgroundColor: "#C41E3A",
        textColor: "#FFFFFF"
      },
      {
        name: "Pizza Napoli Express",
        description: "Wood-fired Neapolitan pizzas made with imported Italian ingredients and traditional recipes.",
        city: "Naples",
        country: "Italy",
        locationAddress: "Via dei Tribunali, 32, 80138 Napoli",
        category: "Italian Restaurant", 
        backgroundColor: "#228B22",
        textColor: "#FFFFFF"
      },
      {
        name: "Burger Palace NYC",
        description: "Gourmet burgers made with premium ingredients and served with hand-cut fries.",
        city: "New York",
        country: "USA",
        locationAddress: "123 Broadway, Manhattan, NY 10001",
        category: "American Restaurant",
        backgroundColor: "#FF1493",
        textColor: "#FFFFFF"
      },
      {
        name: "Curry House Mumbai",
        description: "Authentic Indian curries and tandoor specialties with traditional spices and recipes.",
        city: "Mumbai",
        country: "India",
        locationAddress: "FC Road, Shivajinagar, Mumbai 411005",
        category: "Indian Restaurant",
        backgroundColor: "#FF8C00",
        textColor: "#FFFFFF"
      }
    ];

    const randomRestaurant = restaurants[Math.floor(Math.random() * restaurants.length)];
    
    return {
      name: randomRestaurant.name,
      description: randomRestaurant.description,
      logo: this.generateRandomImageIPFS(),
      websiteUrl: `https://${randomRestaurant.name.toLowerCase().replace(/\s+/g, '')}.com`,
      instagramUrl: `https://instagram.com/${randomRestaurant.name.toLowerCase().replace(/\s+/g, '')}`,
      tiktokUrl: `https://tiktok.com/@${randomRestaurant.name.toLowerCase().replace(/\s+/g, '')}`,
      city: randomRestaurant.city,
      country: randomRestaurant.country,
      locationAddress: randomRestaurant.locationAddress,
      backgroundColor: randomRestaurant.backgroundColor,
      textColor: randomRestaurant.textColor,
      category: randomRestaurant.category
    };
  }

  // Generate random coupon metadata following the schema
  generateCouponMetadata() {
    const coupons = [
      {
        name: "2 for 1 Tacos",
        description: "Buy one taco and get another one completely free! Valid for all taco varieties.",
        visibility: "public",
        category: "Food Discount"
      },
      {
        name: "Free Appetizer",
        description: "Get a complimentary appetizer with any main course order.",
        visibility: "public", 
        category: "Food Bonus"
      },
      {
        name: "20% Off Total Bill",
        description: "Enjoy 20% discount on your entire order, excluding beverages.",
        visibility: "public",
        category: "Percentage Discount"
      },
      {
        name: "Free Dessert",
        description: "Complimentary dessert of your choice with any meal purchase.",
        visibility: "public",
        category: "Food Bonus"
      },
      {
        name: "Happy Hour Special",
        description: "50% off on all beverages between 4 PM - 6 PM.",
        visibility: "public",
        category: "Time-Limited Offer"
      },
      {
        name: "Student Discount",
        description: "15% discount for students with valid ID card.",
        visibility: "public",
        category: "Special Discount"
      }
    ];

    const randomCoupon = coupons[Math.floor(Math.random() * coupons.length)];
    
    // Generate random attributes
    const attributes = [
      { trait_type: "Coupon Type", value: randomCoupon.category },
      { trait_type: "Validity", value: this.getRandomValidityPeriod() },
      { trait_type: "Usage Limit", value: "One per customer" },
      { trait_type: "Minimum Order", value: this.getRandomMinimumOrder() },
      { trait_type: "Restaurant Type", value: this.getRandomRestaurantType() }
    ];

    return {
      name: randomCoupon.name,
      description: randomCoupon.description,
      image: this.generateRandomImageIPFS(),
      visibility: randomCoupon.visibility,
      attributes: attributes
    };
  }

  generateRandomImageIPFS() {
    // Use existing IPFS hashes for images to avoid uploading actual images
    const existingIPFSImages = [
      "ipfs://bafkreidkftqrspl5n5ru26ma5i5tz5pfbxtpi4aoawhnl6kou4f3c3ivym",
      "ipfs://bafybeihgxdzljxb26q6nf3r3eifqeedsvt2eubqtskghpme66cgjyw4fra",
      "ipfs://bafkreiac3t35fklpiwqonav2vj4x2dh6x2zugkdu7dsh6zkaq5jr33lcwy",
      "ipfs://QmExampleImageCID1234567890abcdef",
      "ipfs://QmAnotherImageCID9876543210fedcba"
    ];
    
    return existingIPFSImages[Math.floor(Math.random() * existingIPFSImages.length)];
  }

  getRandomValidityPeriod() {
    const periods = ["30 days", "60 days", "90 days", "6 months", "1 year"];
    return periods[Math.floor(Math.random() * periods.length)];
  }

  getRandomMinimumOrder() {
    const minimums = ["No minimum", "$10 minimum", "$15 minimum", "$20 minimum", "$25 minimum"];
    return minimums[Math.floor(Math.random() * minimums.length)];
  }

  getRandomRestaurantType() {
    const types = ["Fast Food", "Casual Dining", "Fine Dining", "Food Truck", "Cafe", "Bar & Grill"];
    return types[Math.floor(Math.random() * types.length)];
  }
}

module.exports = IPFSHelper; 