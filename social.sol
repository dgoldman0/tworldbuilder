pragma solidity ^0.4.25;

/* The Social Aspect of the Game Associated with WorldBuilder */
// I'm still not sure how to integrate these contracts together. That's something I have to learn about Solidity

// What will the social contract have? It'll have information about the user profile, will make sure there's enough WORLD in the person's account to fund access to their profile, and also have information about towns which are collections of buildings
// One thing that I think I'll have to change is the horribly simplistic way in which buidlings are constructed in builder.sol, which is based on the original version. A struct is probably going to be a better idea, even if it's more work.
contract Social {
  struct town {
    uint id;
  }
}
