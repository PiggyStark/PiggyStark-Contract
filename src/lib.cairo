pub mod interfaces {
    pub mod ierc20;
    pub mod ipiggystark;
    pub mod itargetsavings;
    pub mod inostra;
    pub mod iavnu;
}

pub mod structs {
    pub mod piggystructs;
    pub mod target_savings_structs;
}

pub mod contracts {
    pub mod piggystark;
    pub mod target_savings;
    pub mod token;
}

pub mod errors {
    pub mod piggystark_errors;
}