#[starknet::contract]
mod ownable {

    use starknet::ContractAddress;
    
    #[storage] 
    struct Storage { // here we store stuff, in our case, who is the owner
        owner:  ContractAddress,  
        data: felt252,
    } // next to initialize a value we use a constructor

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnershipTransferred: OwnershipTransferred,
    }
    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        #[key]
        prev_owner: ContractAddress,
        #[key]  // events are very cheap compared to storage, sometimes you just want to emit an event and use an indexer to see what happened on your contract
        new_owner: ContractAddress, // fields set as keys to query the events, can add any datatype that is serializeable
    }






    #[constructor] // when we deploy, we call the constructor. Purpose is to initialize the sate of the contract
    fn constructor( // it's about setting up the initial conditions or configurations
        ref self: ContractState,
        initial_owner: ContractAddress, // use constructor to set the initial owner of a ownable contract. ContractAddress is serializeable so we can use it as an input
    ) {
        self.owner.write(initial_owner); // once constructor is called, we write in the storage. use self to refer to the contract itself + storage name value + write it, aka change the state, ≠ read
         // aka, when we call, we want to put the initial owner value (ContractAddress) inside the contract storage
    }                 // now we want to ownable contract to resolve functions only called by the actual owner. So let's have some functions that can verify the owner before the call is done
                        // so we start by doing an interface to state that our contratc will expose some functions

    #[starknet::interface] 
    trait IData<TContractState> { // could also be <T>, it's a placeholder for the generic type we are passing
        fn get_data(self: @TContractState) -> felt252; //get data as a felt, get data is done by everybody, but set data can only be done by owner
        fn set_data(ref self: TContractState, new_value: felt252); // here we modify so we use a reference (whereas snapshot is readonly), and set it to a new value with is a felt
}

    #[external(v0)]
    impl OwnableDataImpl of IData<ContractState> {
        fn get_data(self: @ContractState) -> felt252 {
            return self.data.read();  // if no semi-colon, it returns the actual data, a function expecting a felt will return the result of read as a felt
            
        }

        fn set_data(ref self: ContractState, new_value: felt252) { // here we want to write the new_value, we pay gas bc we change 
            self.only_owner(); // explicity self parameter, to pass the contract state, we have to pass it, get snapshot because function below is expecting snapshot, it is being called and will not modify the state because it is a self
            self.data.write(new_value); // added ; because we don't want to return anything

        } // so, we have a contract with 2 exposed functions (external) set_data and __wrapper_get_data
          // set_data can only be called by the owner
    }





    #[starknet::interface]
    trait OwnableTrait<T> {
        fn transfer_ownership(ref self: T, new_owner: starknet::ContractAddress); // yes, even though we're inside the module, I add starknet:: because we would have to do it if the interface was outside of the module (at the tippy top)
        fn owner(self: @T) -> starknet::ContractAddress;
    }

    #[external(v0)]
    impl OwnableTraitImpl of OwnableTrait<ContractState> {
        fn transfer_ownership(
            ref self: ContractState, 
            new_owner: ContractAddress) 
        {
            self.only_owner();
            let prev_owner = self.owner.read();
            self.owner.write(new_owner); // we now have to emit our event wer have to say which ckind of event we want to emit

            self.emit(Event::OwnershipTransferred(OwnershipTransferred { // you could also use an enum instead of the name of the structure
                prev_owner, // let's emit an event of the above struct, we have a previous owner and a new owner
                new_owner, // because we have the same name for the variables, Cairo will directly inject the value inside
            }));
        }

        fn owner(self: @ContractState) -> ContractAddress {
            self.owner.read() // we want to return the value which is in the storage 
        }
    }









    #[generate_trait] // when generating a data interface, the trait has to be defined, it's to avoid writing traits all over the place
    impl PrivateMethods of PrivateMethodsTrait { 
        fn only_owner(self:@ContractState) { // function takes a snapshot
            let caller = starknet::get_caller_address(); //get_caller_address when called in contract it will give you exactly what the contract is calling. It'sd the account contract that is calling the contract you are targeting, not your wallet (i.e., AA)
            assert(caller == self.owner.read(), 'Caller is not the owner'); // the caller should be the owner (8:47) in the set_data function, where we can change the state of stuff
        }
    }


} 