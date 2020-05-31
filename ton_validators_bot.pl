#!/usr/bin/perl

#perl -MCPAN -e 'install "WWW::Telegram::BotAPI"'
#perl -MCPAN -e 'install "Mojo::UserAgent"'
#perl -MCPAN -e 'install "Mojo::JSON"'

use strict;
use warnings;
use WWW::Telegram::BotAPI;  
use Data::Dumper;
use HTTP::Request ();
use LWP::UserAgent;
use JSON::MaybeXS qw(encode_json decode_json); 
use MIME::Base64 qw/decode_base64/;
use Digest::SHA qw(sha256_hex);


my $bot_token = '1231231234:AAAABBBBCCCCDDDDEEEEFFFF00001111234';
my $api_url = 'https://api.telegram.org/bot%s/%s';
my $url = 'https://eu-central-1.large.net.ton.dev/graphql';

my $prev_key_block_seqno = get_prev_key_block_seqno();
print "graphql API OK, \$prev_key_block_seqno = " . $prev_key_block_seqno . "\n";

my $query_p1p32p34p36;
my %p1p32p34p36 = get_p1p32p34p36 ();
#print $p1p32p34p36{"p1"}, "\n";
my %node_ids = get_node_id ();
#    while ( my ($key, $value) = each(%node_ids) ) {
#        print "$key => $value\n";
#    }


my $api = WWW::Telegram::BotAPI->new (
    token => $bot_token,
    api_url => $api_url,
  ##  force_lwp => 1 #  
    async => 1 # WARNING: may fail if Mojo::UserAgent is not available!
);
my $me = $api->getMe or die "could not getMe";
print "I am ". Dumper($me);



#say $api->getMe->{result}{username};
my $start_message_en = "Hello!\nI am [FreeTON project](https://freeton.org/join) bot\nI help validators to be sure that their node works and signs FreeTON blockchain blocks correctly.\nI will automatically monitor your node and write you a message if something goes wrong.\nIn order to start monitoring - tell me your Account address\ne.g.:\n\`\`\`\n-1:11B3EA2508596241863A73A95CA5378E67746CCD6E4361580123000011112222\n\`\`\`";
my $sorry_message_en = "sorry, valid only Account address, ADNL address or validator election Public key\ne.g.\n\`\`\`\n-1:11B3EA2508596241863A73A95CA5378E67746CCD6E4361580123000011112222\n\`\`\`";
my $need_more_symbols_en = "I found more then one item. Please send me more symbols\n";
my $nothing_found_adnl_en = "Nothing found. Your ADNL address or Public key is not selected as validators. Or maybe wrong input. Please try again";
my $nothing_found_account_en = "Nothing found. Your Account address is not selected as validators.";
my $updates;
my $offset;
while (1) {
	$updates = $api->getUpdates({timeout => 30, $offset?(offset => $offset):()});
	unless ($updates and ref $updates eq "HASH" and $updates->{ok}) {
		warn "updates weird";
		next;
	}
	for my $u (@{$updates->{result}}) {
		 $offset = $u->{update_id} + 1 if $u->{update_id} >= $offset;
#		 print "Message from " . $u->{message}{from}{username};
#            print " Message text = " . $u->{message}{text} . "\n";
		 print Dumper($u);
            if ($u->{message}{text} eq '/start' ) {
                $api->sendMessage({
                    chat_id => $u->{message}{chat}{id},
                    text => "$start_message_en",
				    parse_mode => "Markdown",
                });
			    next; 
            }
            if ($u->{message}{text} =~ /(-1:[\dABCDEFabcdef]{64})/ ) {
                my $account_addr = $1;
				my %found_account = check_account($account_addr);
				my $count = scalar(%found_account);
				print "Count = $count \n" ;
				
				if ($count == 0) {
					$api->sendMessage({
						chat_id => $u->{message}{chat}{id},
						text => "$nothing_found_account_en",
					});				
					next;
				}
				my ($last_sign, $node_seq_no) = check_node_block_last_sign($node_ids{$found_account{'p34'}{'public_key'}});
				my ($last_block_time, $seq_no) = get_last_block_time();
				my $sign_diff = $last_block_time - $last_sign;
				my $seq_no_diff = $seq_no - $node_seq_no;
				#print Dumper \%found_account;
				#print "----------------\n";
				my $text;
				$text .= "Account: \`$account_addr\`\n";
				$text .= "You Account is won *Previous* election of validators!\nPublic key: \`$found_account{'p32'}{'public_key'}\`\nADNL address: \`$found_account{'p32'}{'adnl_addr'}\`\n\n" if ( $found_account{'p32'}{'type'} eq "p32" );
				$text .= "You Account is won *Current* election of validators!\nPublic key: \`$found_account{'p34'}{'public_key'}\`\nADNL address: \`$found_account{'p34'}{'adnl_addr'}\`\n\n" if ( $found_account{'p34'}{'type'} eq "p34" );
				$text .= "You Account is won *Current* election of validators!\nPublic key: \`$found_account{'p36'}{'public_key'}\`\nADNL address: \`$found_account{'p36'}{'adnl_addr'}\`\n\n" if ( defined ($found_account{'p36'}{'type'}) );
				$text .= "Your account last sign block have *$sign_diff* seconds ago.\nThis is *$seq_no_diff* block ago.";
                $api->sendMessage({
                    chat_id => $u->{message}{chat}{id},
                    text => "$text",
					parse_mode => "Markdown",
                });
                next;
            }
			if ($u->{message}{text} =~ /([\dABCDEFabcdef]{5,64})/ ) {
                my $adnl_addr = $1; 
				my @found_adnl = check_adnl($adnl_addr);
				my $count = scalar(@found_adnl);
				print "Count = $count \n" ;
				if ($count > 1) {
					$api->sendMessage({
						chat_id => $u->{message}{chat}{id},
						text => "$need_more_symbols_en",
					});				
					next;
				}
				if ($count == 0) {
					$api->sendMessage({
						chat_id => $u->{message}{chat}{id},
						text => "$nothing_found_adnl_en",
					});				
					next;
				}
				if ($count == 1) {
				my ($last_sign, $node_seq_no) = check_node_block_last_sign($node_ids{$found_adnl[0]{'public_key'}});
				my ($last_block_time, $seq_no) = get_last_block_time();
				my $sign_diff = $last_block_time - $last_sign;
				my $seq_no_diff = $seq_no - $node_seq_no;
					my $text = "You won the ";
					$text .= "*Previous* election of validators!\n" if ( $found_adnl[0]{'type'} eq "p32" );
					$text .= "*Current* election of validators!\n" if ( $found_adnl[0]{'type'} eq "p34" );
					$text .= "*Next* election of validators!\n" if ( $found_adnl[0]{'type'} eq "p36" );
					$text .= "Public key: \`$found_adnl[0]{'public_key'}\`\nADNL address: \`$found_adnl[0]{'adnl_addr'}\`\n\n";
					$text .= "Your validator\'s Public key last sign block time is *$sign_diff* seconds ago.\nThis is *$seq_no_diff* block ago.";
					$api->sendMessage({
						chat_id => $u->{message}{chat}{id},
						text => "$text",
						parse_mode => "Markdown",
					});				
					next;
				}
            }
		$api->sendMessage({
			chat_id => $u->{message}{chat}{id},
			text => $sorry_message_en,
			parse_mode => "Markdown",
		});
	}
}

sub get_prev_key_block_seqno {
	my $resp_prev_key_block_seqno = getQUERY ("{  blocks(orderBy: {path: \"seq_no\", direction: DESC}, limit: 1) {    prev_key_block_seqno  }}");
	my $decode_json_prev_key_block_seqno = decode_json $resp_prev_key_block_seqno;
	#print Dumper $decode_json_prev_key_block_seqno;
	my $arr = $decode_json_prev_key_block_seqno->{"data"}->{"blocks"};
	for my $item ( @$arr ){
		return $item->{"prev_key_block_seqno"};
	}
}

sub get_p1p32p34p36 {
my $resp = getQUERY ("{  blocks(filter: {seq_no: {eq: $prev_key_block_seqno}, workchain_id: {eq: -1}}) {    master {      config {        p1      }    }    master {      config {        p32 {          utime_since          utime_until          total          total_weight          list {            public_key            adnl_addr            weight          }        }      }    }    master {      config {        p34 {          utime_since          utime_until          total          total_weight          list {            public_key            adnl_addr            weight          }        }      }    }    master {      config {        p36 {          utime_since          utime_until          total          total_weight          list {            public_key            adnl_addr            weight          }        }      }    }  }}");
my $decode_json = decode_json $resp;
$query_p1p32p34p36 = $decode_json;
my %p1p32p34p36 ; 
#print Dumper $decode_json;
my $arr = $decode_json->{"data"}->{"blocks"};
for my $item ( @$arr ){
   $p1p32p34p36{"p1"} = $item->{"master"}->{"config"}->{"p1"};
#   print $p1p32p34p36{"p1"} . "\n";
   $p1p32p34p36{"p32_utime_since"} = $item->{"master"}->{"config"}->{"p32"}->{"utime_since"};
   $p1p32p34p36{"p32_utime_until"} = $item->{"master"}->{"config"}->{"p32"}->{"utime_until"};
   $p1p32p34p36{"p32_total"} = $item->{"master"}->{"config"}->{"p32"}->{"total"};
   $p1p32p34p36{"p32_total_weight"} = $item->{"master"}->{"config"}->{"p32"}->{"total_weight"};
   my $p32_list = $item->{"master"}->{"config"}->{"p32"}->{"list"};
   for my $validator ( @$p32_list ) {
#      print $validator->{"public_key"} . "    p32\n";
#      print $validator->{"adnl_addr"} . "\n";
#      print $validator->{"weight"} . "\n";
   }
   $p1p32p34p36{"p34_utime_since"} = $item->{"master"}->{"config"}->{"p34"}->{"utime_since"};
   $p1p32p34p36{"p34_utime_until"} = $item->{"master"}->{"config"}->{"p34"}->{"utime_until"};
   $p1p32p34p36{"p34_total"} = $item->{"master"}->{"config"}->{"p34"}->{"total"};
   $p1p32p34p36{"p34_total_weight"} = $item->{"master"}->{"config"}->{"p34"}->{"total_weight"};
   my $p34_list = $item->{"master"}->{"config"}->{"p34"}->{"list"};
   for my $validator ( @$p34_list ) {
#      print $validator->{"public_key"} . "    p34\n";
#      print $validator->{"adnl_addr"} . "\n";
#      print $validator->{"weight"} . "\n";
   }
   $p1p32p34p36{"p36_utime_since"} = $item->{"master"}->{"config"}->{"p36"}->{"utime_since"};
   $p1p32p34p36{"p36_utime_until"} = $item->{"master"}->{"config"}->{"p36"}->{"utime_until"};
   $p1p32p34p36{"p36_total"} = $item->{"master"}->{"config"}->{"p36"}->{"total"};
   $p1p32p34p36{"p36_total_weight"} = $item->{"master"}->{"config"}->{"p36"}->{"total_weight"};
   my $p36_list = $item->{"master"}->{"config"}->{"p36"}->{"list"};
   for my $validator ( @$p36_list ) {
#      print $validator->{"public_key"} . "    p36\n";
#      print $validator->{"adnl_addr"} . "\n";
#      print $validator->{"weight"} . "\n";
   }
}
return %p1p32p34p36;
}

sub check_adnl {
my ($adnl) = @_;
my @found_adnl;
#my %found_adnl;
my $arr = $query_p1p32p34p36->{"data"}->{"blocks"};
for my $item ( @$arr ){	
    my $i = 0;
    my $p32_list = $item->{"master"}->{"config"}->{"p32"}->{"list"};
    for my $validator ( @$p32_list ) {
        if ( ($validator->{"adnl_addr"} =~ /($adnl)/i) or ($validator->{"public_key"}=~ /($adnl)/i) ){
			$found_adnl[$i]{"adnl_addr"} = $validator->{"adnl_addr"};
			$found_adnl[$i]{"public_key"} = $validator->{"public_key"};
			$found_adnl[$i]{"weight"} = $validator->{"weight"};
			$found_adnl[$i]{"type"} = "p32";
			$i++;
            print "Found ADNL: $1 " . $validator->{"adnl_addr"} . "  in p32 list\n";
            print $validator->{"public_key"} . "    p32\n";
            print $validator->{"weight"} . "\n";
        } 
    }
    my $p34_list = $item->{"master"}->{"config"}->{"p34"}->{"list"};
    for my $validator ( @$p34_list ) {
        if ( ($validator->{"adnl_addr"} =~ /($adnl)/i) or ($validator->{"public_key"}=~ /($adnl)/i) ){
			$found_adnl[$i]{"adnl_addr"} = $validator->{"adnl_addr"};
			$found_adnl[$i]{"public_key"} = $validator->{"public_key"};
			$found_adnl[$i]{"weight"} = $validator->{"weight"};
			$found_adnl[$i]{"type"} = "p34";
			$i++;
            print "Found ADNL: $1 " . $validator->{"adnl_addr"} . "  in p34 list\n";
            print $validator->{"public_key"} . "    p34\n";
            print $validator->{"weight"} . "\n";
        }
    }
    my $p36_list = $item->{"master"}->{"config"}->{"p36"}->{"list"};
    for my $validator ( @$p36_list ) {
        if ( ($validator->{"adnl_addr"} =~ /($adnl)/i) or ($validator->{"public_key"}=~ /($adnl)/i) ){
			$found_adnl[$i]{"adnl_addr"} = $validator->{"adnl_addr"};
			$found_adnl[$i]{"public_key"} = $validator->{"public_key"};
			$found_adnl[$i]{"weight"} = $validator->{"weight"};
			$found_adnl[$i]{"type"} = "p36";
			$i++;
            print "Found ADNL: $1 " . $validator->{"adnl_addr"} . "  in p36 list\n";
            print $validator->{"public_key"} . "    p36\n";
            print $validator->{"weight"} . "\n";
        }
    }
    #$i++;
}
return @found_adnl;
}

sub check_account{
   my ($account_addr) = @_;
   my %found;
   my %found_account;
   my $resp = getQUERY ("{  messages(filter: {src: {eq: \"$account_addr\"}, dst: {eq: \"-1:$p1p32p34p36{'p1'}\"}}, orderBy: {path: \"now\", direction: DESC}, limit: 3) {    boc  }}");
   my $decode_json = decode_json $resp;
#   print Dumper $decode_json;
   my $arr = $decode_json->{"data"}->{"messages"};
      for my $item ( @$arr ){
       #  print $item->{"boc"} . "\n";
         my $item_boc_decode_base64 = unpack('H*', decode_base64($item->{"boc"}));
       #  print $item_boc_decode_base64 . "\n";
        %found = findADNL ($item_boc_decode_base64); 
		if (defined ($found{"type"}) ) {
			$found_account{$found{type}}{"adnl_addr"} = $found{"adnl_addr"};
			$found_account{$found{type}}{"public_key"} = $found{"public_key"};
			$found_account{$found{type}}{"weight"} = $found{"weight"};
			$found_account{$found{type}}{"type"} = $found{"type"};
		}
      }
	return %found_account;
}

sub check_node_block_last_sign {
	my ($node_id) = @_;
	my $gen_utime;
	my $seq_no;
    my $resp = getQUERY ("{  blocks_signatures(filter: {signatures: {any: {node_id: {eq: \"$node_id\"}}}}, orderBy: {path: \"gen_utime\", direction: DESC}, limit: 1) {    gen_utime    seq_no  }}");
	my $decode_json = decode_json $resp;
	my $arr = $decode_json->{"data"}->{"blocks_signatures"};
	for my $item ( @$arr ){
		$gen_utime = $item->{"gen_utime"};
		$seq_no = $item->{"seq_no"};
	}
	return $gen_utime, $seq_no;
}

sub get_last_block_time {
	my $gen_utime;
	my $seq_no;
    my $resp = getQUERY ("{  blocks_signatures(orderBy: {path: \"gen_utime\", direction: DESC}, limit: 1) {    gen_utime    seq_no  }}");
	my $decode_json = decode_json $resp;
	my $arr = $decode_json->{"data"}->{"blocks_signatures"};
	for my $item ( @$arr ){
		$gen_utime = $item->{"gen_utime"};
		$seq_no = $item->{"seq_no"};
	}
	return $gen_utime, $seq_no;
}

sub findADNL {
   my ($boc) = @_;
   my %found;
   my $arr = $query_p1p32p34p36->{"data"}->{"blocks"};
   for my $item ( @$arr ){
      my $i = 0;
      my $p32_list = $item->{"master"}->{"config"}->{"p32"}->{"list"};
      for my $validator ( @$p32_list ) {
         if ( $boc =~ /($validator->{"adnl_addr"})/i ){
		 	$found{"adnl_addr"} = $validator->{"adnl_addr"};
			$found{"public_key"} = $validator->{"public_key"};
			$found{"weight"} = $validator->{"weight"};
			$found{"type"} = "p32";
			$i++;
            print "Your Account is validator: $1 in p32 list\n";
            print $validator->{"public_key"} . "    p32\n";
            print $validator->{"weight"} . "\n";
         }
      }
      my $p34_list = $item->{"master"}->{"config"}->{"p34"}->{"list"};
      for my $validator ( @$p34_list ) {
         if ( $boc =~ /($validator->{"adnl_addr"})/i ){
			$found{"adnl_addr"} = $validator->{"adnl_addr"};
			$found{"public_key"} = $validator->{"public_key"};
			$found{"weight"} = $validator->{"weight"};
			$found{"type"} = "p34";
			$i++;
            print "Your Account is validator: $1 in p34 list\n";
            print $validator->{"public_key"} . "    p34\n";
            print $validator->{"weight"} . "\n";
         }
      }
      my $p36_list = $item->{"master"}->{"config"}->{"p36"}->{"list"};
      for my $validator ( @$p36_list ) {
         if ( $boc =~ /($validator->{"adnl_addr"})/i ){
			$found{"adnl_addr"} = $validator->{"adnl_addr"};
			$found{"public_key"} = $validator->{"public_key"};
			$found{"weight"} = $validator->{"weight"};
			$found{"type"} = "p36";
			$i++;
            print "Your Account is validator: $1 in p36 list\n";
            print $validator->{"public_key"} . "    p36\n";
            print $validator->{"weight"} . "\n";

         }
      }
   }
   return %found;
}

sub get_node_id {
my %node_ids;
my $arr = $query_p1p32p34p36->{"data"}->{"blocks"};
for my $item ( @$arr ){	
    my $p32_list = $item->{"master"}->{"config"}->{"p32"}->{"list"};
    for my $validator ( @$p32_list ) {
		$node_ids{"$validator->{'public_key'}"} = node_id_calculate ($validator->{"public_key"});
    }
    my $p34_list = $item->{"master"}->{"config"}->{"p34"}->{"list"};
    for my $validator ( @$p34_list ) {
		$node_ids{"$validator->{'public_key'}"} = node_id_calculate ($validator->{"public_key"});
    }
    my $p36_list = $item->{"master"}->{"config"}->{"p36"}->{"list"};
    for my $validator ( @$p36_list ) {
		$node_ids{"$validator->{'public_key'}"} = node_id_calculate ($validator->{"public_key"});
    }
}
return %node_ids;
}

sub node_id_calculate {
	my ($public_key) = @_;
	my $sha = Digest::SHA->new(256);
	my $hash_str = "c6b41348" . "$public_key";
	my $packSHA = pack('H*', $hash_str);
	$sha->add_bits($packSHA, 288);
	return $sha->hexdigest;
}

sub getQUERY {
   my ($query) = @_;
   my $header = ['Content-Type' => 'application/json; charset=UTF-8'];
   my $data = {'operationName' => "",
      'query' => $query,
      'variables' => '{}'};
   my $encoded_data = encode_json($data);
   my $r = HTTP::Request->new('POST', $url, $header, $encoded_data);
   my $ua = LWP::UserAgent->new();
   my $response = $ua->request($r);
   die "$url error: ", $response->status_line
    unless $response->is_success;
   die "Weird content type at $url -- ", $response->content_type
    unless $response->content_type eq 'application/json';
#   print $response->content;
   return $response->content;
} 
